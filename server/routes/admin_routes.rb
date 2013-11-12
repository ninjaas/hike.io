require_relative "../server"
require_relative "../model/hike"

class HikeApp < Sinatra::Base

	get "/admin/v1/reviews/:review_id", :provides => "json" do
		return 403 if user_needs_changes_reviewed?
		review = Review[:string_id => params[:review_id]]
		return 404 if not review
		review.to_json
	end

	# Ideally this would be a PUT on the review, but since email clients 
	# don't appreciate javascript, a GET seemed like a better option
	get "/admin/v1/reviews/:review_id/accept", :provides => "json" do
		return 403 if user_needs_changes_reviewed?
		review = Review[:string_id => params[:review_id]]
		return 404 if not review
		return 400 if review.api_verb != "put" && review.api_verb != "post" && review.api_verb != "delete"
		return 409 if review.status != Review::STATUS_UNREVIEWED

		if review.api_verb == "put"
			hike = Hike[:string_id => review.hike_string_id]
			return 409 if not hike
			return 409 if hike.edit_time > review.creation_time
			hike.update_from_json(JSON.parse(review.api_body))
			hike.edit_time = review.creation_time
			hike.save_changes
			redirect_url = "/hikes/#{hike.string_id}"
		elsif review.api_verb == "post" 
			hike = Hike.create_from_json(JSON.parse(review.api_body))
			hike.creation_time = review.creation_time
			hike.edit_time = review.creation_time
			hike.save
			redirect_url = "/hikes/#{hike.string_id}"
		elsif review.api_verb == "delete"
			hike = Hike[:string_id => review.hike_string_id]
			return 409 if not hike
			hike.cascade_destroy
			redirect_url = "/"
		end

		review.reviewer = current_user_id
		review.status = Review::STATUS_ACCEPTED
		review.edit_time = Time.now
		review.save_changes

		redirect redirect_url
	end

	get "/admin/v1/reviews/:review_id/reject", :provides => "json" do
		return 403 if user_needs_changes_reviewed?
		review = Review[:string_id => params[:review_id]]
		return 404 if not review
		return 400 if review.api_verb != "put" && review.api_verb != "post" && review.api_verb != "delete"
		return 409 if review.status != Review::STATUS_UNREVIEWED
		review.reviewer = current_user_id
		review.status = Review::STATUS_REJECTED
		review.edit_time = Time.now
		review.save_changes

		if review.api_verb == "put"
			hike = Hike[:string_id => review.hike_string_id]
			if hike
				redirect "/hikes/#{hike.string_id}"
			else
				redirect "/"
			end
		else
			redirect "/"
		end
	end
end