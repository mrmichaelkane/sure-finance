# frozen_string_literal: true

module AdvancedReports
  class DashboardController < BaseController
    def index
      @breadcrumbs = [ [ t("advanced_reports.dashboard.index.breadcrumb_home"), root_path ],
                       [ t("advanced_reports.dashboard.index.breadcrumb_reports"), reports_path ],
                       [ t("advanced_reports.dashboard.index.title"), nil ] ]
    end
  end
end
