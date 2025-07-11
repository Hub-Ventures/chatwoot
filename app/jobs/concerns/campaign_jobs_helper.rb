module CampaignJobsHelper
  extend ActiveSupport::Concern

  # Common configuration constants
  DEFAULT_SAFETY_LIMIT = 10_000
  DEFAULT_BATCH_SIZE = 100
  DEFAULT_TIMEOUT = 30.minutes

  private

  # Log campaign start with statistics
  def log_campaign_start(campaign, contact_count)
    Rails.logger.info "[Campaign Job] Starting #{campaign.class.name} #{campaign.id} with #{contact_count} contacts"
  end

  # Log campaign completion with statistics
  def log_campaign_completion(campaign, stats)
    Rails.logger.info "[Campaign Job] #{campaign.class.name} #{campaign.id} completed - " \
                      "Processed: #{stats[:processed]}, Successful: #{stats[:successful]}, Failed: #{stats[:failed]}"
  end

  # Log campaign failure
  def log_campaign_failure(campaign, error)
    Rails.logger.error "[Campaign Job] #{campaign.class.name} #{campaign.id} failed: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
  end

  # Check if failure rate is acceptable
  def acceptable_failure_rate?(stats, threshold = 0.5)
    return true if stats[:processed] < 10 # Require minimum sample size

    failure_rate = stats[:failed].to_f / stats[:processed]
    failure_rate <= threshold
  end

  # Format duration for logging
  def format_duration(seconds)
    return "#{seconds.round(2)}s" if seconds < 60

    minutes = seconds / 60
    return "#{minutes.round(1)}m" if minutes < 60

    hours = minutes / 60
    "#{hours.round(1)}h"
  end
end