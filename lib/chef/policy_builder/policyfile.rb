#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Tim Hinderliter (<tim@opscode.com>)
# Author:: Christopher Walters (<cw@opscode.com>)
# Author:: Daniel DeLeo (<dan@getchef.com>)
# Copyright:: Copyright 2008-2014 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/log'
require 'chef/rest'
require 'chef/run_context'
require 'chef/config'
require 'chef/node'

class Chef
  module PolicyBuilder

    # Policyfile is an experimental policy builder implementation that gets run
    # list and cookbook version information from a single document.
    #
    # == WARNING
    # This implementation is experimental. It may be changed in incompatible
    # ways in minor or even patch releases, or even abandoned altogether. If
    # using this with other tools, you may be forced to upgrade those tools in
    # lockstep with chef-client.
    #
    # == Unsupported Options:
    # * override_runlist:: maybe replace this with a resource filter to select
    # specific resources from the resource_collection?
    # * specific_recipes:: put more design thought into this use case.
    # * run_list in json_attribs:: will be ignored (warn/error?)
    class Policyfile

      attr_reader :events
      attr_reader :node
      attr_reader :node_name
      attr_reader :ohai_data
      attr_reader :json_attribs
      attr_reader :run_context

      def initialize(node_name, ohai_data, json_attribs, override_runlist, events)
        @node_name = node_name
        @ohai_data = ohai_data
        @json_attribs = json_attribs
        @events = events

        @node = nil
      end

      ## API Compat ##
      # Methods related to unsupported features

      # Override run_list is not supported.
      def original_runlist
        nil
      end

      # Override run_list is not supported.
      def override_runlist
        nil
      end

      # Policyfile gives you the run_list already expanded, no expansion is
      # performed here.
      def run_list_expansion
        nil
      end

      ## PolicyBuilder API ##

      # In client-server operation, loads the node state from the server. In
      # chef-solo operation, builds a new node object.
      def load_node
        events.node_load_start(node_name, Chef::Config)
        Chef::Log.debug("Building node object for #{node_name}")

        if Chef::Config[:solo]
          @node = Chef::Node.build(node_name)
        else
          @node = Chef::Node.find_or_create(node_name)
        end
      rescue Exception => e
        # TODO: wrap this exception so useful error info can be given to the
        # user.
        events.node_load_failed(node_name, e, Chef::Config)
        raise
      end

      # Applies environment, external JSON attributes, and override run list to
      # the node, Then expands the run_list.
      #
      # === Returns
      # node<Chef::Node>:: The modified node object. node is modified in place.
      def build_node
        # consume_external_attrs may add items to the run_list. Save the
        # expanded run_list, which we will pass to the server later to
        # determine which versions of cookbooks to use.
        node.reset_defaults_and_overrides
        node.consume_external_attrs(ohai_data, @json_attribs)

        # everything below this line is wrong
        raise "FIXME"

        validate_policyfile
        apply_policyfile_attributes

        Chef::Log.info("Run List is [#{run_list}]")
        Chef::Log.info("Run List expands to [#{run_list_with_versions_for_display.join(', ')}]")


        events.node_load_completed(node, run_list_with_versions_for_display, Chef::Config)

        node
      end

      def setup_run_context(specific_recipes=nil)
        raise "FIXME"

        # TODO: This file vendor stuff is duplicated and initializing it with a
        # block traps a reference to this object in a global context which will
        # prevent it from getting GC'd. Simplify it.
        if Chef::Config[:solo]
          Chef::Cookbook::FileVendor.on_create { |manifest| Chef::Cookbook::FileSystemFileVendor.new(manifest, Chef::Config[:cookbook_path]) }
          cl = Chef::CookbookLoader.new(Chef::Config[:cookbook_path])
          cl.load_cookbooks
          cookbook_collection = Chef::CookbookCollection.new(cl)
          run_context = Chef::RunContext.new(node, cookbook_collection, @events)
        else
          Chef::Cookbook::FileVendor.on_create { |manifest| Chef::Cookbook::RemoteFileVendor.new(manifest, api_service) }
          cookbook_hash = sync_cookbooks
          cookbook_collection = Chef::CookbookCollection.new(cookbook_hash)
          run_context = Chef::RunContext.new(node, cookbook_collection, @events)
        end

        run_context
      end

      ## Internal Public API ##

      def run_list_with_versions_for_display
        run_list.map do |recipe_spec|
          cookbook, recipe = parse_recipe_spec(recipe_spec)
          lock_data = cookbook_lock_for(cookbook)
          display = "#{cookbook}::#{recipe}@#{lock_data["version"]} (#{lock_data["identifier"][0...7]})"
          display
        end
      end

      class PolicyfileError < StandardError; end

      def parse_recipe_spec(recipe_spec)
        rmatch = recipe_spec.match(/recipe\[([^:]+)::([^:]+)\]/)
        if rmatch.nil?
          raise PolicyfileError, "invalid recipe specification #{recipe_spec} in Policyfile from #{policyfile_location}"
        else
          [rmatch[1], rmatch[2]]
        end
      end

      def cookbook_lock_for(cookbook_name)
        policy["cookbook_locks"][cookbook_name]
      end

      def run_list
        policy["run_list"]
      end

      def policy
        @policy ||= http_api.get("data/policyfiles/#{deployment_group}")
      end

      def policyfile_location
        "data/policyfiles/#{deployment_group}"
      end

      class ConfigurationError < StandardError; end

      def deployment_group
        Chef::Config[:deployment_group] or
          raise ConfigurationError, "Setting `deployment_group` is not configured."
      end

      def http_api
        @api_service ||= Chef::REST.new(config[:chef_server_url])
      end


    end
  end
end

