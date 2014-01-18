#
# Author:: Daniel DeLeo (<dan@getchef.com>)
# Copyright:: Copyright 2014 Chef Software, Inc.
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

require 'spec_helper'
require 'chef/policy_builder'

describe Chef::PolicyBuilder::Policyfile do

  let(:node_name) { "joe_node" }
  let(:ohai_data) { {"platform" => "ubuntu", "platform_version" => "13.04", "fqdn" => "joenode.example.com"} }
  let(:json_attribs) { {"run_list" => []} }
  let(:override_runlist) { "recipe[foo::default]" }
  let(:events) { Chef::EventDispatch::Dispatcher.new }
  let(:policy_builder) { Chef::PolicyBuilder::Policyfile.new(node_name, ohai_data, json_attribs, override_runlist, events) }

  # Convert a SHA1 (160 bit) hex string into an x.y.z version number where the
  # maximum value is smaller than a postgres BIGINT (signed 64bit, so 63 usable
  # bits). This requires enterprise Chef or open source server 11.1.0+ (currently not released)
  #
  # The SHA1 is devided as follows:
  # * "major": first 14 chars (56 bits)
  # * "minor": next 14 chars (56 bits)
  # * "patch": last 12 chars (48 bits)
  def id_to_dotted(sha1_id)
    major = sha1_id[0...14]
    minor = sha1_id[14...28]
    patch = sha1_id[28..40]
    decimal_integers =[major, minor, patch].map {|hex| hex.to_i(16) }
    decimal_integers.join(".")
  end

  let(:example1_lock_data) do
    # based on https://github.com/danielsdeleo/chef-workflow2-prototype/blob/master/skeletons/basic_policy/Policyfile.lock.json
    {
      "identifier" => "168d2102fb11c9617cd8a981166c8adc30a6e915",
      "version" => "2.3.5",
      # NOTE: for compatibility mode we include the dotted id in the policyfile to enhance discoverability.
      "dotted_decimal_identifier" => id_to_dotted("168d2102fb11c9617cd8a981166c8adc30a6e915"),
      "source" => { "path" => "./cookbooks/demo" },
      "scm_identifier"=> {
        "vcs"=> "git",
        "rev_id"=> "9d5b09026470c322c3cb5ca8a4157c4d2f16cef3",
        "remote"=> nil
      }
    }
  end

  let(:example2_lock_data) do
    {
      "identifier" => "feab40e1fca77c7360ccca1481bb8ba5f919ce3a",
      "version" => "4.2.0",
      # NOTE: for compatibility mode we include the dotted id in the policyfile to enhance discoverability.
      "dotted_decimal_identifier" => id_to_dotted("feab40e1fca77c7360ccca1481bb8ba5f919ce3a"),
      "source" => { "api" => "https://community.getchef.com/api/v1/cookbooks/example2" }
    }
  end

  let(:policyfile_default_attributes) { {} }
  let(:policyfile_override_attributes) { {} }

  let(:policyfile_run_list) { ["recipe[example1::default]", "recipe[example2::server]"] }

  let(:parsed_policyfile_json) do
    {
      "run_list" => policyfile_run_list,

      "cookbook_locks" => {
        "example1" => example1_lock_data,
        "example2" => example2_lock_data
      },

      "default_attributes" => policyfile_default_attributes,
      "override_attributes" => policyfile_override_attributes
    }
  end

  let(:http_api) { double("Chef::REST") }

  describe "unsupported features" do

    it "errors when given an override_runlist" do
      pending
    end

    it "errors when json_attribs contains a run_list" do
      pending
    end

    it "errors when an environment is configured" do
      # maybe this counts as a warning instead?
      pending
    end

    it "errors if the policyfile json contains any non-recipe items" do
      pending
    end

    it "errors if the policyfile json contains non-fully qualified recipe items" do
      pending
    end

  end

  describe "when using compatibility mode" do

    before do

      policy_builder.stub(:http_api).and_return(http_api)
    end

    it "errors when no deployment_group is configured" do
      pending
    end

    context "when the deployment_group cannot be found" do

      it "passes error information to the event system" do
        pending
        # TODO: also make sure something acceptable happens with the error formatters
      end
    end

    context "and a deployment_group is configured" do
      before do
      # TODO: agree on this name
        Chef::Config[:deployment_group] = "example-deployment-group"

        http_api.should_receive(:get).with("data/policyfiles/example-deployment-group").and_return(parsed_policyfile_json)
      end

      it "fetches the policy file from a data bag item" do
        expect(policy_builder.policy).to eq(parsed_policyfile_json)
      end

      it "extracts the run_list from the policyfile" do
        expect(policy_builder.run_list).to eq(policyfile_run_list)
      end

      it "extracts the cookbooks and versions for display from the policyfile" do
        expected = [
          "example1::default@2.3.5 (168d210)",
          "example2::server@4.2.0 (feab40e)"
        ]

        expect(policy_builder.run_list_with_versions_for_display).to eq(expected)
      end
    end

    describe "building the node object" do

      it "resets default and override data" do
        pending
      end

      it "applies ohai data" do
        pending
      end

      it "applies attributes from json file" do
        pending
      end

      it "applies attributes from the policyfile" do
        pending
      end

      it "sets the policyfile's run_list on the node object" do
        pending
      end

    end

  end


end
