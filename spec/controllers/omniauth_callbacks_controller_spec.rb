require "rails_helper"

RSpec.describe OmniauthCallbacksController, type: :controller do

  class MockStrategy
    def name
      "canvas"
    end
  end

  before do
    setup_application_instance
    request.env["devise.mapping"] = Devise.mappings[:user] # If using Devise
    request.env["omniauth.strategy"] = MockStrategy.new
  end

  describe "GET canvas" do
    it "should pass through with valid auth" do
      user = FactoryBot.create :user_canvas
      authentication = user.authentications.find_by(provider: "canvas")
      canvas_opts = {
        "uid" => authentication.uid,
        "info" => {
          "url" => authentication.provider_url,
        },
      }
      request.env["omniauth.auth"] = get_canvas_omniauth(canvas_opts)
      ai = @application_instance
      root_domain = Rails.application.secrets.application_root_domain
      path = "applications/#{ai.application_id}/application_instances/#{ai.id}/installs"
      oauth_complete_url = "//#{Application::ADMIN}.#{root_domain}#{admin_root_path}##{path}"
      response = get :canvas, params: {
        admin_oauth_aii: ai.id,
        canvas_url: "https://example.instructure.com",
      }

      expect(response).to redirect_to oauth_complete_url
    end

    it "should pass through with valid auth and a user logged in via lti credentials" do
      user = FactoryBot.create :user_canvas
      authentication = user.authentications.find_by(provider: "canvas")
      canvas_opts = {
        "uid" => authentication.uid,
        "info" => {
          "url" => authentication.provider_url,
        },
      }
      request.env["omniauth.auth"] = get_canvas_omniauth(canvas_opts)
      user.lti_user_id = User.oauth_lti_user_id(request.env["omniauth.auth"])
      user.save!
      response = get :canvas, params: {
        canvas_url: "https://example.instructure.com",
        oauth_consumer_key: "ltikey",
      }

      expect(warden.authenticated?(:user)).to be true
      expect(warden.user).to eq(user)
      expect(response).to have_http_status 200
      expect(assigns(:is_lti_launch)).to eq true
    end

    it "should redirect to origin without auth" do
      origin_url = "http://example.com"
      request.env["omniauth.origin"] = origin_url

      response = get :canvas
      expect(response).to redirect_to origin_url
    end

    it "should redirect with error params" do
      origin_url = "http://example.com"
      request.env["omniauth.origin"] = origin_url
      error_params = { error: "failure" }
      response = get :canvas, params: {
        canvas_url: "https://example.instructure.com",
      }.merge(error_params)

      expect(response).to redirect_to "#{origin_url}?#{error_params.to_query}"
    end

    it "should render oauth error page when no origin is available" do
      response = get :canvas

      expect(response).to have_http_status 403
    end

    context "when the request is an LTI Advantage resource link request" do
      let(:lti_launch) { FactoryBot.create(:lti_launch) }

      before do
        setup_canvas_lti_advantage(application_instance: @application_instance)

        user = FactoryBot.create :user_canvas
        authentication = user.authentications.find_by(provider: "canvas")
        canvas_opts = {
          "uid" => authentication.uid,
          "info" => {
            "url" => authentication.provider_url,
          },
        }
        request.env["omniauth.auth"] = get_canvas_omniauth(canvas_opts)

        @response = get :canvas, params: {
          canvas_url: @canvas_url,
          id_token: @id_token,
          lti_launch_config: lti_launch.config.to_json,
        }
      end

      it "includes LTI launch config in client settings" do
        expect(@response.body).to include("\"lti_launch_config\":#{lti_launch.config.to_json}")
      end

      it "includes the context ID in client settings" do
        expect(@response.body).to include("\"context_id\":#{@context_id.to_json}")
      end

      it "includes the Canvas URL in client settings" do
        expect(@response.body).to include("\"canvas_url\":#{@application_instance.site.url.to_json}")
      end
    end

    context "when the request is an LTI Advantage deep linking request" do
      let(:lti_launch) { FactoryBot.create(:lti_launch) }

      before do
        setup_canvas_lti_advantage(
          application_instance: @application_instance,
          message_type: "LtiDeepLinkingRequest",
        )

        user = FactoryBot.create :user_canvas
        authentication = user.authentications.find_by(provider: "canvas")
        canvas_opts = {
          "uid" => authentication.uid,
          "info" => {
            "url" => authentication.provider_url,
          },
        }
        request.env["omniauth.auth"] = get_canvas_omniauth(canvas_opts)

        @response = get :canvas, params: {
          canvas_url: @canvas_url,
          id_token: @id_token,
          lti_launch_config: lti_launch.config.to_json,
        }
      end

      it "includes deep link settings in client settings" do
        expect(@response.body).to include("deep_link_settings")
      end
    end
  end
end
