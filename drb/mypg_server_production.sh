#!/bin/sh

RUBY=/usr/local/bin/ruby
P=/var/www/my.personalgenomes.org/current/drb
SERVER=mypg_server.rb

case "$1" in
    start)
			echo "Starting mypg_server..."
			/usr/bin/daemon -r -U -o $P/../log/mypg_server.error1 -E $P/../log/mypg_server.error -O $P/../log/mypg_server.log -n mypg_server_production $RUBY $P/$SERVER production
  ;;
    stop)
			echo "Stopping mypg_server..."
			/usr/bin/daemon --stop -n mypg_server_production
  ;;
    restart)
			/usr/bin/daemon --running -n mypg_server_production
			if [ "$?" = "0" ]; then
				echo "Restarting mypg_server..."
				/usr/bin/daemon --restart -n mypg_server_production
			else
				echo "mypg_server was not running. Starting it now..."
				/usr/bin/daemon -r -U -o $P/../log/mypg_server.error1 -E $P/../log/mypg_server.error -O $P/../log/mypg_server.log -n mypg_server_production $RUBY $P/SERVER production
			fi
  ;;
  *)
  echo "Usage: $0 {start|stop|restart}" >&2
  exit 1
  ;;
esac

