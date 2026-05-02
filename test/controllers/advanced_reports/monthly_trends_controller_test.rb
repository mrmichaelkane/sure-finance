require "test_helper"

class AdvancedReports::MonthlyTrendsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @account = accounts(:depository)
    @category = categories(:food_and_drink)
  end

  test "index renders successfully" do
    get advanced_reports_monthly_trends_path

    assert_response :ok
    assert_select "h1", text: I18n.t("advanced_reports.monthly_trends.index.title")
    assert_select "h2", text: I18n.t("advanced_reports.monthly_trends.report.chart.title")
  end

  test "index filters by selected account and category" do
    get advanced_reports_monthly_trends_path(account_id: @account.id, category_id: @category.id, mode: "both")

    assert_response :ok
    assert_includes @response.body, @account.name
    assert_includes @response.body, ERB::Util.html_escape(@category.name)
  end

  test "invalid custom range falls back gracefully" do
    get advanced_reports_monthly_trends_path(
      preset: "custom",
      start_date: "2026-05-10",
      end_date: "2026-05-01"
    )

    assert_response :ok
    assert_includes @response.body, I18n.t("advanced_reports.monthly_trends.index.invalid_date_range")
  end
end
