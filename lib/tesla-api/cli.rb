require 'thor'

module TeslaAPI
  class CLI < Thor
    include Thor::Actions

    MAPPING_URLS = {"google" => "http://maps.google.com?q=%{lat},%{long}",
                    "osm" => "http://www.openstreetmap.org/?mlat=%{lat}&mlon=%{long}#map=19/%{lat}/%{long}"}

    class_option :login
    class_option :password

    def initialize(*args)
      super

      @login    = ENV["TESLA_API_LOGIN"]
      @password = ENV["TESLA_API_PASSWORD"]
    end

    desc "range", "Gets the current ranges of the vehicle"
    option :miles, :type => :boolean, :desc => "Give ranges in miles instead of kilometers"
    def range
      if options[:miles]
        puts "#{vehicle.charge_state.battery_range_miles} miles (rated)"
        puts "#{vehicle.charge_state.estimated_battery_range_miles} miles (estimated)"
        puts "#{vehicle.charge_state.ideal_battery_range_miles} miles (ideal)"
      else
        puts "#{vehicle.charge_state.battery_range_kilometers} kilometers (rated)"
        puts "#{vehicle.charge_state.estimated_battery_range_kilometers} kilometers (estimated)"
        puts "#{vehicle.charge_state.ideal_battery_range_kilometers} kilometers (ideal)"
      end
    end

    desc "inside_temp", "Gets the inside temperature"
    def inside_temp
      display(vehicle.climate_state.inside_temp_celsius, "C")
    end

    desc "outside_temp", "Gets the outside temperature"
    def outside_temp
      display(vehicle.climate_state.outside_temp_celsius.inspect, "C")
    end

    desc "lock", "Locks the car doors"
    def lock
      vehicle.lock_door!

      puts "Locking..."

      sleep 1

      puts vehicle.state.locked? ? "Doors are locked" : "Doors are unlocked"
    end

    desc "unlock", "Unlocks the car doors"
    def unlock
      vehicle.unlock_door!

      puts "Unlocking..."

      sleep 1

      puts vehicle.state.locked? ? "Doors are locked" : "Doors are unlocked"
    end

    desc "cool TEMP", "Starts the A/C on the car and set it to the desired temp"
    def cool(temp)
      vehicle.set_temperature!(temp, temp)
      vehicle.auto_conditioning_start!
    end

    desc "where", "Generates a map link showing where your car is"
    option :"map-provider", :desc => "Which map provider to use. One of: #{MAPPING_URLS.keys.join(", ")}", :default => MAPPING_URLS.keys.first
    def where
      if options[:"map-provider"].empty?
        provider = MAPPING_URLS.keys.first
      else
        provider = options[:"map-provider"]
      end

      if MAPPING_URLS.keys.include?(provider)
        drive_state = vehicle.drive_state
        url = MAPPING_URLS[provider]
        puts url % {:lat => drive_state.latitude, :long => drive_state.longitude}
      else
        puts "Unknown map provider '#{provider}', choose one of #{MAPPING_URLS.keys.join(", ")}."
        exit 1
      end
    end

    protected

    def vehicle
      @vehicle ||= begin
        populate_auth(options)

        tesla = TeslaAPI::Connection.new(@login, @password)

        unless tesla.vehicle
          puts "Could not connect to the API and access your vehicle"
          exit 1
        end

        tesla.vehicle
      rescue TeslaAPI::Errors::NotLoggedIn => ex
        puts "Invalid login"
        exit 1
      end
    end

    def display(value, units)
      if value.to_s.empty?
        puts "Could not read data from the vehicle"
      else
        puts "#{value} #{units}"
      end
    end

    def populate_auth(options)
      @login    = options[:login]    if options[:login]
      @password = options[:password] if options[:password]
    end
  end
end

