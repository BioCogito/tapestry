class PublicGeneticDataController < ApplicationController
  skip_before_filter :login_required
  skip_before_filter :ensure_enrolled
  skip_before_filter :ensure_latest_consent
  skip_before_filter :ensure_recent_safety_questionnaire
  def index
    @data_type_options = []
    @data_type_options << ['All data types', nil]
    @known_data_type = {}
    UserFile::DATA_TYPES.each { |k,v|
      if v == 'other'
        @data_type_options << [v, v]
      else
        @data_type_options << [k, v]
      end
      @known_data_type[v] = true
    }
    @datasets = UserFile.joins(:user).merge(User.enrolled.not_suspended).includes(:user) |
      Dataset.published.joins(:participant).merge(User.enrolled.not_suspended).includes(:participant)
    if params[:data_type] and !params[:data_type].empty?
      @datasets.reject! { |d|
        ![d.data_type, d.class.to_s].index(params[:data_type]) and
        !(params[:data_type] == 'other' and !@known_data_type[d.data_type])
      }
    end
    @datasets.sort! { |b,a|
      a_date = a.respond_to?(:published_at) ? a.published_at : a.created_at
      b_date = b.respond_to?(:published_at) ? b.published_at : b.created_at
      cmp = a_date <=> b_date
      if cmp != 0 and (a_date - b_date).abs > 3600
        cmp
      elsif a.participant.pgp_id and b.participant.pgp_id
        a.participant.pgp_id <=> b.participant.pgp_id
      elsif a.participant.pgp_id
        -1
      elsif b.participant.pgp_id
        1
      else
        cmp
      end
    }
    respond_to do |format|
      format.html
      format.json {
        respond_with @datasets, :model => Dataset
      }
    end
  end

  def statistics
    @datasets = UserFile.joins(:user).merge(User.enrolled.not_suspended).includes(:user) |
      Dataset.published.joins(:participant).merge(User.enrolled.not_suspended).includes(:participant)
    @data_type_stats = {}
    @data_type_name = {}
    @coverage_series = {}
    @datasets_series = {}
    @t0 = nil
    UserFile::DATA_TYPES.each do |longversion, shortversion|
      @data_type_name[shortversion] = longversion
    end
    @datasets.sort_by(&:published_at).each do |d|
      data_type = d.data_type
      data_type = 'other' unless @data_type_name.has_key? data_type
      next unless 0 == @data_type_name[data_type].index('genetic data - ')
      stats = @data_type_stats[data_type] ||= {
        :positions_covered => 0,
        :N => 0
      }
      add_to_coverage_series = false
      begin
        stats[:positions_covered] += d.report_metadata[:called_num]
        add_to_coverage_series = true
      rescue
        # ignore base-counting fail
      end
      stats[:N] += 1

      @t0 ||= (d.published_at.to_f*1000).floor

      @datasets_series[data_type] ||= {
        'data' => [[@t0, 0]],
        'label' => data_type + ' datasets',
        'data_type' => data_type
      }
      @datasets_series[data_type]['data'] << [(d.published_at.to_f*1000).floor,
                                              @datasets_series[data_type]['data'].last[1]]
      @datasets_series[data_type]['data'] << [(d.published_at.to_f*1000).floor,
                                              stats[:N]]

      if add_to_coverage_series
        @coverage_series[data_type] ||= {
          'data' => [[@t0, 0]],
          'label' => data_type + ' coverage',
          'data_type' => data_type
        }
        @coverage_series[data_type]['data'] << [(d.published_at.to_f*1000).floor,
                                                @coverage_series[data_type]['data'].last[1]]
        @coverage_series[data_type]['data'] << [(d.published_at.to_f*1000).floor,
                                                stats[:positions_covered]]
      end
    end

    # Extend each series to Time.now and sort by total coverage
    @datasets_series, @coverage_series = [@datasets_series, @coverage_series].collect do |series|
      series.keys.each do |s|
        series[s]['data'] << [Time.now.to_f*1000,
                              series[s]['data'].last[1]]
      end
      series.values.sort_by { |s|
        begin
          0-@coverage_series[s['data_type']]['data'].last[1]
        rescue
          2**32 - s['data'].last[1]
        end
      }
    end
  end
end
