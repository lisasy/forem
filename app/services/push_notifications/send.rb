module PushNotifications
  class Send
    def self.call(user:, title:, body:, payload:)
      new(user: user, title: title, body: body, payload: payload).call
    end

    def initialize(user:, title:, body:, payload:)
      @user = user
      @title = title
      @body = body
      @payload = payload
    end

    def call
      return unless FeatureFlag.enabled?(:mobile_notifications)

      @user.devices.find_each do |device|
        device.create_notification(@title, @body, @payload)
      end

      # perform_in(30.seconds) is key: The background worker will execute Rpush.push which will send out all
      # pending notifications. This means we don't need to run it for every PN. PushNotifications::DeliverWorker
      # has a constraint that will execute the job only once (30 seconds from now). So if we need to send 1 PN
      # every 5 seconds we only execute this once every 30s (no duplicate/unnecessary processing).
      # If no PNs are scheduled to be sent for a 6h span then 0 jobs are executed.
      PushNotifications::DeliverWorker.perform_in(30.seconds)
    end
  end
end