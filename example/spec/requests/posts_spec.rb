require 'rails_helper'

## Posts
# Contains the list and details of the available posts
RSpec.describe "Posts", type: :request, rest_api_name: "Apitecto Example API", doc_sort_order: 1 do

  let :client_headers do
    { "Accept" => "application/json" }
  end

  ## Posts List [/posts]
  # This is the list of posts available through the API.
  #
  # The list the list list list!!!
  describe "Post List" do

    ## Retrieve the posts list [GET]
    # Retrieves a list of available posts.
    #
    # + Parameters
    #   + limit (optional)
    #   + offset (optional)
    #
    describe "GET /posts", action_name: "Retrieve posts list" do

      # Create a list of posts for each example:
      before :each do
        create_list :post, 2
      end

      it "succeeds" do
        get posts_path, {}, client_headers
        expect(response).to have_http_status :ok
      end

    end

    ## Create a new post [POST]
    # Creates a new post in the API.
    #
    # + Parameters
    #   + limit (optional)
    #   + offset (optional)
    #
    describe "POST /posts", action_name: "Create a new post" do
      it "succeeds" do
        post posts_path, { post: attributes_for(:post) }, client_headers
        expect(response).to have_http_status :created
      end
      ################################################

      # context "with valid parameters" do
      #
      #
      #
      # end
      #
      # context "with an invalid parameter" do
      #
      #   it "fails" do
      #     post posts_path, { post: attributes_for(:invalid_post) }, client_headers
      #     expect(response).to have_http_status :unprocessable_entity
      #   end
      #
      # end

    end
  end

end

########################
