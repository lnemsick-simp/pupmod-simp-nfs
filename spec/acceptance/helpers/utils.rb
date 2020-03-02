module Acceptance
  module Helpers
    module Utils

      # Create a string that can be inserted into the body of a
      # nfs::client::mount in a manifest and which contains mount option
      #
      # +config+: Hash of of mount options
      #  Hash keys:
      #  * :nfsv3     - When true, nfs::client::mount::nfs_version is set to 3.
      #                 Otherwise, the default will apply.
      #  * :nfs_sec   - Value of nfs::client::mount::sec
      #  * :nfsd_port - When set, value of nfs::client::mount::nfsd_port
      #                 Otherwise, the default will apply.
      #  * :stunnel_nfsd_port - When set, value of
      #                 nfs::client::mount::stunnel_nfsd_port. Otherwise,
      #                 the default will apply
      # * :mount_stunnel - When set, value of nfs::client::mount::stunnel.
      #                  Otherwise, the default will apply.
      #
      def build_mount_options(config)
        options = ''
        if config[:nfsv3]
          options += "  nfs_version => 3,\n"
        end

        if config[:nfs_sec]
          options += "  sec         => #{config[:nfs_sec]},\n"
        end

        if config[:nfsd_port]
          options += "  nfsd_port   => #{config[:nfsd_port]},\n"
        end

        if config[:stunnel_nfsd_port]
          options += "  stunnel_nfsd_port => #{config[:stunnel_nfsd_port]},\n"
        end

        unless config[:mount_stunnel].nil?
          if config[:mount_stunnel]
            options += "  stunnel    => true,\n"
          else
            options += "  stunnel    => false,\n"
          end
        end

        options
      end

      # code copied from simp-core's acceptance tests
      # FIXME - Move to simp-beaker-helpers

      # @returns array of IPV4 networks configured on a host
      #
      # +host+: Host (object)
      #
      def host_networks(host)
        require 'json'
        require 'ipaddr'
        networking = JSON.load(on(host, 'facter --json networking').stdout)
        networking['networking']['interfaces'].delete_if { |key,value| key == 'lo' }
        networks = networking['networking']['interfaces'].map do |key,value|
          net_mask = IPAddr.new(value['netmask']).to_i.to_s(2).count("1")
          "#{value['network']}/#{net_mask}"
        end
        networks
      end

      # @returns the internal IPV4 network info for a host or nil if
      #   none can be found
      #
      # +host+: Host (object)
      #
      # This method ASSUMES the first non-loopback interface without DHCP
      # configured or with DHCP that does not matches the outermost 'dhcp'
      # key is the interface used for the internal network.
      def internal_network_info(host)
        networking = JSON.load(on(host, 'facter --json networking').stdout)
        internal_ip_info = nil
        main_dhcp = networking['networking']['dhcp']
        networking['networking']['interfaces'].each do |interface,settings|
          next if interface == 'lo'
          if ( ! settings.has_key?('dhcp') || (settings['dhcp'] != main_dhcp ) )
            internal_ip_info = {
              :interface => interface,
              :ip        => settings['ip'],
              :netmask   => settings['netmask']
            }
            break
          end
        end
        internal_ip_info
      end

      def print_test_config(hieradata, manifest)
        puts '>'*80
        if hieradata.is_a?(Hash)
          puts "Hieradata:\n#{hieradata.to_yaml}"
        else
          puts "Hieradata:\n#{hieradata}"
        end
        puts '-'*80
        puts "Manifest:\n#{manifest}"
        puts '<'*80
      end

      # Temporary hack to try to ensure connection to a host after reboot
      # with beaker 4.14.1
      # TODO: Remove this when beaker is fixed
      def wait_for_reboot_hack(host)
        # Sometimes beaker connects to the host before it has rebooted, so first sleep
        # to give the host time to get farther along in its shutdown
        wait_seconds = ENV['NFS_TEST_REBOOT_WAIT'] ?  ENV['NFS_TEST_REBOOT_WAIT'] : 10
        sleep(wait_seconds)

        # If beaker has already connected successfully before the reboot, it will think
        # the necessity to reconnect is a failure.  So it will close the connection and
        # raise an exception. If we catch that exception and retry, beaker will then
        # create a new connection.
        tries = ENV['NFS_TEST_RECONNECT_TRIES'] ?  ENV['NFS_TEST_RECONNECT_TRIES'] : 10
        begin
          on(host, 'uptime')
        rescue Beaker::Host::CommandFailure => e
          if e.message.include?('connection failure') && (tries > 0)
            puts "Retrying due to << #{e.message.strip} >>"
            tries -= 1
            sleep 1
            retry
          else
            raise e
          end
        end
      end
    end
  end
end
