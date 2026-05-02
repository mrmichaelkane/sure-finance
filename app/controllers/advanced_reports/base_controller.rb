# frozen_string_literal: true

module AdvancedReports
  class BaseController < ApplicationController
    layout "advanced_reports"

    before_action :set_account_scope

    private
      def set_account_scope
        @accounts = Current.family.accounts.active
      end
  end
end
