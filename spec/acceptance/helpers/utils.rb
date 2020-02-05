module Acceptance
  module Helpers
    module Utils
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

    end
  end
end
