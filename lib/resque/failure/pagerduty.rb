require 'resque'
require 'redphone/pagerduty'

module Resque
  module Failure
    # A Resque failure backend that handles exceptions by triggering
    # incidents in the Pagerduty API
    class Pagerduty < Base
      class << self
        # The subdomain for the Pagerduty endpoint url
        attr_accessor :subdomain

        # The default GUID of the Pagerduty "Generic API" service to be notified.
        # This is the "service key" listed on a Generic API's service detail page
        # in the Pagerduty app.
        attr_accessor :service_key

        # The user for authenticating to Pagerduty
        attr_accessor :username

        # The password for authenticating to Pagerduty
        attr_accessor :password
      end

      # The GUID of the Pagerduty "Generic API" service to be notified.
      # If a pagerduty_service_key is provided on the payload class, then the
      # payload service_key will be used; otherwise, the default service_key
      # can be configured on the failure backend class.
      #
      # @see .configure
      # @see .service_key
      def service_key
        if (payload['class'].respond_to?(:pagerduty_service_key) &&
            !payload['class'].pagerduty_service_key.nil?)
          payload['class'].pagerduty_service_key
        else
          self.class.service_key
        end
      end

      # Configures the failure backend for the Pagerduty API.
      #
      # @example Full configuration
      #   Resque::Failure::Pagerduty.configure do |config|
      #     config.subdomain = 'my_subdomain'
      #     config.service_key = '123abc456def'
      #     config.username = 'my_user'
      #     config.password = 'my_pass'
      #   end
      #
      # @see .subdomain
      # @see .service_key
      # @see .username
      # @see .password
      def self.configure
        yield self
        self
      end

      # Resets configured values.
      # @see .configure
      def self.reset
        self.subdomain = nil
        self.service_key = nil
        self.username = nil
        self.password = nil
      end

      # Trigger an incident in Pagerduty when a job fails.
      def save
        pagerduty_client.trigger_incident(
          :description => "Job raised an error: #{self.exception.to_s}",
          :details => {:queue => queue,
                       :class => payload['class'].to_s,
                       :args => payload['arguments'],
                       :exception => exception.inspect,
                       :backtrace => exception.backtrace.join("\n")}
        )
      end

      private
      def pagerduty_client
        Redphone::Pagerduty.new(
          :service_key => self.service_key,
          :subdomain => self.class.subdomain,
          :user => self.class.username,
          :password => self.class.password
        )
      end
    end
  end
end
