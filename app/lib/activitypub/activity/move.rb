# frozen_string_literal: true

class ActivityPub::Activity::Move < ActivityPub::Activity
  def perform
    return if origin_account.uri != object_uri

    target_account = account_from_uri(target_uri)

    return if target_account.nil? || !target_account.also_known_as.include?(origin_account.uri)

    # In case for some reason we didn't have a redirect for the profile already, set it
    origin_account.update(moved_to_account: target_account) if origin_account.moved_to_account_id.nil?

    # Initiate a re-follow for each follower
    origin_account.followers.local.select(:id).find_in_batches do |follower_accounts|
      UnfollowFollowWorker.push_bulk(follower_accounts.map(&:id)) do |follower_account_id|
        [follower_account_id, origin_account.id, target_account.id]
      end
    end
  end

  private

  def origin_account
    @account
  end

  def target_uri
    value_or_id(@json['target'])
  end
end
