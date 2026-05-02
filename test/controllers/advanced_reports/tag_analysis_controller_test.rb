require "test_helper"

class AdvancedReports::TagAnalysisControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @account = accounts(:depository)
    @tag_one = tags(:one)
    @tag_two = tags(:two)
  end

  test "index renders successfully" do
    get advanced_reports_tag_analysis_index_path

    assert_response :ok
    assert_select "h1", text: I18n.t("advanced_reports.tag_analysis.index.title")
    assert_select "h2", text: I18n.t("advanced_reports.tag_analysis.report.chart.title"), count: 1
    assert_includes @response.body, I18n.t("advanced_reports.tag_analysis.report.table.view_transactions")
  end

  test "index shows comparison filters" do
    get advanced_reports_tag_analysis_index_path(account_id: @account.id, compare_tag_a_id: @tag_one.id, compare_tag_b_id: @tag_two.id)

    assert_response :ok
    assert_includes @response.body, @account.name
    assert_includes @response.body, @tag_one.name
    assert_includes @response.body, @tag_two.name
  end

  test "index handles no tags gracefully" do
    sign_in users(:empty)

    get advanced_reports_tag_analysis_index_path

    assert_response :ok
    assert_includes @response.body, I18n.t("advanced_reports.tag_analysis.report.empty.no_tags_title")
  end

  test "invalid custom range falls back gracefully" do
    get advanced_reports_tag_analysis_index_path(
      preset: "custom",
      start_date: "2026-05-10",
      end_date: "2026-05-01"
    )

    assert_response :ok
    assert_includes @response.body, I18n.t("advanced_reports.tag_analysis.index.invalid_date_range")
  end
end
