require 'json'
require 'rest-client'

module Build
  class VagrantBox
    attr_reader :reference

    APPLIANCE_URL_ROOT = "https://releases.manageiq.org"
    VAGRANT_URL_ROOT   = "https://app.vagrantup.com/api/v1/"
    VAGRANT_USER_NAME  = "manageiq"

    def self.create(reference)
      if ENV['VAGRANT_CLOUD_TOKEN'].to_s.empty?
        puts "VAGRANT_CLOUD_TOKEN environment variable is not set, not creating vagrant box/version"
      else
        puts "Creating vagrant box/version for #{reference}"
        new(reference).run
      end
    end

    def initialize(reference)
      @reference = reference
    end

    def run
      # Check if file exists
      appliance = "#{APPLIANCE_URL_ROOT}/manageiq-vagrant-#{reference}.box"
      appliance_response = head_request(appliance)
      if appliance_response.code != 200
        puts "#{appliance} doesn't exist"
        return
      end

      branch, minor_patch, milestone = reference.split("-")
      major = (branch[0].ord - 96).to_s     # jansa = 10, kasparov = 11
      minor_patch << ".0" unless minor_patch.include?(".")
      version = "#{major}.#{minor_patch}"
      version << "-#{milestone}" if milestone

      box_base = "#{VAGRANT_URL_ROOT}/box/#{VAGRANT_USER_NAME}/#{branch}"
      headers  = { Content_Type:  "application/json",
                   Authorization: "Bearer #{ENV['VAGRANT_CLOUD_TOKEN']}" }

      # Create box (e.g. jansa)
      puts "Creating box: #{branch}"
      body = { box: { username:          VAGRANT_USER_NAME,
                      name:              branch,
                      short_description: "ManageIQ Open-Source Management Platform http://manageiq.org",
                      is_private:        false }
             }
      create_item(box_base, "#{VAGRANT_URL_ROOT}/boxes", headers, body)

      # Create version (e.g. 10.1.0)
      puts "Creating version: #{version}"
      head_url = "#{box_base}/version/#{version}"
      post_url = "#{box_base}/versions"
      body     = { version: { version:     version,
                              description: "#{reference} release" }
                 }
      create_item(head_url, post_url, headers, body)

      # Create 'virtualbox' provider
      puts "Creating provider: 'virtualbox'"
      head_url = "#{box_base}/version/#{version}/provider/virtualbox"
      post_url = "#{box_base}/version/#{version}/providers"
      body     = { provider: { name: "virtualbox",
                               url:  appliance,
                               checksum: appliance_response.headers[:etag].delete('"'),
                               checksum_type: "md5" }
                 }
      # Delete provider if already exists, image might have been rebuilt
      delete_request(head_url, headers) if head_request(head_url)

      create_item(head_url, post_url, headers, body)
    end

    private

    def create_item(head_url, post_url, headers, post_body)
      rc = head_request(head_url)
      case rc.code
      when 200
        puts "Already exists: #{head_url}"
      when 404
        rc = post_request(post_url, headers, post_body.to_json)
        if rc.code > 300
          puts rc.body
          raise "Failed to create #{post_url}"
        end
      else
        raise "Unknown return code: #{rc.code}"
      end
    end

    def head_request(request)
      send_request("head", request)
    end

    def delete_request(request, headers)
      send_request("delete", request, headers)
    end

    def post_request(request, headers, body)
      send_request("post", request, headers, body)
    end

    def send_request(action, request, headers = nil, body = nil)
        begin
          case action
          when "head"
            RestClient.head(request)
          when "delete"
            RestClient.delete(request, headers)
          when "post"
            RestClient.post(request, body, headers)
          end
        rescue RestClient::ExceptionWithResponse => e
          e.response
        end
    end
  end
end
