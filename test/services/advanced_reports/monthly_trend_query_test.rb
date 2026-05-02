require "test_helper"

class AdvancedReports::MonthlyTrendQueryTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @other_account = accounts(:connected)
    @food_category = categories(:food_and_drink)
    @income_category = categories(:income)
    @filter = AdvancedReports::DateRangeFilter.new(
      start_date: Date.new(2020, 1, 1),
      end_date: Date.new(2020, 4, 30)
    )
  end

  def create_entry(account:, amount:, date:, category:, kind: "standard", **opts)
    account.entries.create!(
      name: "Test entry",
      date: date,
      amount: amount,
      currency: "USD",
      entryable: Transaction.new(kind: kind, category: category, **opts)
    )
  end

  test "builds monthly expenses and rolling average" do
    create_entry(account: @account, amount: 100, date: Date.new(2020, 1, 10), category: @food_category)
    create_entry(account: @account, amount: 200, date: Date.new(2020, 2, 10), category: @food_category)
    create_entry(account: @account, amount: 400, date: Date.new(2020, 3, 10), category: @food_category)
    create_entry(account: @account, amount: 300, date: Date.new(2020, 4, 10), category: @food_category)

    result = AdvancedReports::MonthlyTrendQuery.new(@family, date_range_filter: @filter).call

    assert_equal [ 100.to_d, 200.to_d, 400.to_d, 300.to_d ], result.months.map(&:expense)
    assert_equal [ 100.to_d, 150.to_d, 233.33.to_d, 300.to_d ], result.months.map(&:rolling_expense)
  end

  test "calculates month over month values from expenses by default" do
    create_entry(account: @account, amount: 250, date: Date.new(2020, 3, 10), category: @food_category)
    create_entry(account: @account, amount: 100, date: Date.new(2020, 4, 10), category: @food_category)

    result = AdvancedReports::MonthlyTrendQuery.new(@family, date_range_filter: @filter).call

    assert_equal 100.to_d, result.month_over_month.current_value
    assert_equal 250.to_d, result.month_over_month.previous_value
    assert_equal(-150.to_d, result.month_over_month.change_amount)
    assert_equal(-60.to_d, result.month_over_month.change_percent)
  end

  test "supports income mode summaries" do
    create_entry(account: @account, amount: -1000, date: Date.new(2020, 3, 10), category: @income_category)
    create_entry(account: @account, amount: -1500, date: Date.new(2020, 4, 10), category: @income_category)

    result = AdvancedReports::MonthlyTrendQuery.new(@family, date_range_filter: @filter, mode: "income").call

    assert_equal :income, result.focus_metric
    assert_equal 1500.to_d, result.month_over_month.current_value
    assert_equal 1000.to_d, result.month_over_month.previous_value
    assert_equal 500.to_d, result.month_over_month.change_amount
    assert_equal 50.to_d, result.month_over_month.change_percent
    assert_equal [ 0.to_d, 0.to_d, 333.33.to_d, 833.33.to_d ], result.months.map(&:rolling_income)
    assert_equal 1500.to_d, result.best_month.value
    assert_equal 0.to_d, result.worst_month.value
  end

  test "filters to a selected category" do
    create_entry(account: @account, amount: 120, date: Date.new(2020, 4, 10), category: @food_category)
    create_entry(account: @account, amount: 999, date: Date.new(2020, 4, 12), category: @income_category)

    result = AdvancedReports::MonthlyTrendQuery.new(
      @family,
      date_range_filter: @filter,
      category_id: @food_category.id
    ).call

    april = result.months.detect { |month| month.date == Date.new(2020, 4, 1) }

    assert_equal 120.to_d, april.expense
    assert_equal 0.to_d, april.income
    assert_equal @food_category.name, result.category_name
  end

  test "filters to the selected account ids" do
    create_entry(account: @account, amount: 120, date: Date.new(2020, 4, 10), category: @food_category)
    create_entry(account: @other_account, amount: 400, date: Date.new(2020, 4, 12), category: @food_category)

    result = AdvancedReports::MonthlyTrendQuery.new(
      @family,
      date_range_filter: @filter,
      account_ids: @account.id
    ).call

    april = result.months.detect { |month| month.date == Date.new(2020, 4, 1) }
    assert_equal 120.to_d, april.expense
  end
end
