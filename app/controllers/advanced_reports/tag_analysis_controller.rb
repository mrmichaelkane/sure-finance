# frozen_string_literal: true

module AdvancedReports
  class TagAnalysisController < BaseController
    helper_method :transaction_filter_params

    before_action :set_filters

    def index
      @report = AdvancedReports::TagSpendQuery.new(
        Current.family,
        date_range_filter: @date_range_filter,
        account_ids: @selected_account_id,
        compare_tag_ids: [ @compare_tag_a_id, @compare_tag_b_id ].compact
      ).call

      @breadcrumbs = [
        [ t("advanced_reports.dashboard.index.breadcrumb_home"), root_path ],
        [ t("advanced_reports.dashboard.index.breadcrumb_reports"), reports_path ],
        [ t("advanced_reports.dashboard.index.title"), advanced_reports_dashboard_index_path ],
        [ t("advanced_reports.tag_analysis.index.title"), nil ]
      ]
    end

    private

      def set_filters
        @preset = params[:preset].presence || "last_3_months"
        @tags = Current.family.tags.alphabetically
        @selected_account = @accounts.find_by(id: params[:account_id]) if params[:account_id].present?
        @compare_tag_a = @tags.find_by(id: params[:compare_tag_a_id]) if params[:compare_tag_a_id].present?
        @compare_tag_b = @tags.find_by(id: params[:compare_tag_b_id]) if params[:compare_tag_b_id].present?
        @selected_account_id = @selected_account&.id
        @compare_tag_a_id = @compare_tag_a&.id
        @compare_tag_b_id = @compare_tag_b&.id

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
        flash.now[:alert] = t("advanced_reports.tag_analysis.index.invalid_date_range")
      end

      def transaction_filter_params(tag_name)
        filters = {
          tags: [ tag_name ],
          start_date: @date_range_filter.start_date.iso8601,
          end_date: @date_range_filter.end_date.iso8601
        }

        filters[:account_ids] = [ @selected_account_id ] if @selected_account_id.present?
        filters
      end
  end
end
