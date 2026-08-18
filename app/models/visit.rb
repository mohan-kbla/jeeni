class Visit < ApplicationRecord
  before_validation :truncate_user_agent

  private

  def truncate_user_agent
    self.user_agent = user_agent.to_s[0...255] if user_agent.present?
  end
end
