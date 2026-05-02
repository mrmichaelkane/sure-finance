# frozen_string_literal: true

module AdvancedReports
  class IncomeExpensesController < BaseController
    before_action :set_filters

    def index
      @report = AdvancedReports::IncomeExpensesQuery.new(
        Current.family,
        date_range_filter: @date_range_filter,
        account_ids: @selected_account_id
      ).call

      @breadcrumbs = [
        [ t("advanced_reports.dashboard.index.breadcrumb_home"), root_path ],
        [ t("advanced_reports.dashboard.index.breadcrumb_reports"), reports_path ],
        [ t("advanced_reports.dashboard.index.title"), advanced_reports_dashboard_index_path ],
        [ t("advanced_reports.income_expenses.index.title"), nil ]
      ]
    end

    private

      def set_filters
        @preset = params[:preset].presence || "last_3_months"
        @selected_account = @accounts.find_by(id: params[:account_id]) if params[:account_id].present?
        @selected_account_id = @selected_account&.id

        @date_range_filter = AdvancedReports::DateRangeFilter.new(
          preset: @preset,
          start_date: params[:start_date],
          end_date: params[:end_date]
        )

        return if @date_range_filter.valid?

        handle_invalid_filters
      rescue ArgumentError
        handle_invalid_filters
      end

      def handle_invalid_filters
        @preset = "last_3_months"
        @date_range_filter = AdvancedReports::DateRangeFilter.new(preset: @preset)
        flash.now[:alert] = t("advanced_reports.income_expenses.index.invalid_date_range")
      end
  end
end
