# frozen_string_literal: true

module AdvancedReports
  class BaseController < ApplicationController
    layout "application"

    before_action :set_account_scope

    private
      def set_account_scope
        @accounts = Current.family.accounts.active
      end
  end
end
