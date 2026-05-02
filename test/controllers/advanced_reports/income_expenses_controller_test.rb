require "test_helper"

class AdvancedReports::IncomeExpensesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @account = accounts(:depository)
  end

  test "index renders successfully" do
    get advanced_reports_income_expenses_path

    assert_response :ok
    assert_select "h1", text: I18n.t("advanced_reports.income_expenses.index.title")
    assert_select "h2", text: I18n.t("advanced_reports.income_expenses.report.chart.title")
  end

  test "index filters by selected account" do
    get advanced_reports_income_expenses_path(account_id: @account.id)

    assert_response :ok
    assert_includes @response.body, @account.name
  end

  test "invalid custom range falls back gracefully" do
    get advanced_reports_income_expenses_path(
      preset: "custom",
      start_date: "2026-05-10",
      end_date: "2026-05-01"
    )

    assert_response :ok
    assert_includes @response.body, I18n.t("advanced_reports.income_expenses.index.invalid_date_range")
  end
end
