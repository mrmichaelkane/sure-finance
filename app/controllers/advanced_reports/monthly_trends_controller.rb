# frozen_string_literal: true

module AdvancedReports
  class MonthlyTrendsController < BaseController
    PRESET_OPTIONS = {
      "last_12_months" => -> { [ 11.months.ago.to_date.beginning_of_month, Date.current ] },
      "last_24_months" => -> { [ 23.months.ago.to_date.beginning_of_month, Date.current ] },
      "ytd" => -> { [ Date.current.beginning_of_year, Date.current ] }
    }.freeze

    MODES = %w[expenses income both].freeze

    before_action :set_filters

    def index
      @report = AdvancedReports::MonthlyTrendQuery.new(
        Current.family,
        date_range_filter: @date_range_filter,
        account_ids: @selected_account_id,
        category_id: @selected_category_id,
        mode: @mode
      ).call

      @breadcrumbs = [
        [ t("advanced_reports.dashboard.index.breadcrumb_home"), root_path ],
        [ t("advanced_reports.dashboard.index.breadcrumb_reports"), reports_path ],
        [ t("advanced_reports.dashboard.index.title"), advanced_reports_dashboard_index_path ],
        [ t("advanced_reports.monthly_trends.index.title"), nil ]
      ]
    end

    private

      def set_filters
        @preset = params[:preset].presence || "last_12_months"
        @mode = params[:mode].presence_in(MODES) || "expenses"
        @categories = Current.family.categories.alphabetically_by_hierarchy
        @selected_account = @accounts.find_by(id: params[:account_id]) if params[:account_id].present?
        @selected_category = @categories.find_by(id: params[:category_id]) if params[:category_id].present?
        @selected_account_id = @selected_account&.id
        @selected_category_id = @selected_category&.id

        @date_range_filter =
          if @preset == "custom"
            AdvancedReports::DateRangeFilter.new(
              start_date: params[:start_date],
              end_date: params[:end_date]
            )
          else
            start_date, end_date = resolve_preset(@preset)
            AdvancedReports::DateRangeFilter.new(start_date:, end_date:)
          end

        return if @date_range_filter.valid?

        handle_invalid_filters
      rescue ArgumentError
        handle_invalid_filters
      end

      def resolve_preset(preset)
        resolver = PRESET_OPTIONS[preset]
        raise ArgumentError, "Unknown preset: #{preset}" unless resolver

        resolver.call
      end

      def handle_invalid_filters
        @preset = "last_12_months"
        start_date, end_date = resolve_preset(@preset)
        @date_range_filter = AdvancedReports::DateRangeFilter.new(start_date:, end_date:)
        flash.now[:alert] = t("advanced_reports.monthly_trends.index.invalid_date_range")
      end
  end
end
