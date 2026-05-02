require "test_helper"

class AdvancedReports::IncomeExpensesQueryTest < ActiveSupport::TestCase
  TEST_DATE = Date.new(2020, 6, 15)

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @other_account = accounts(:connected)
    @filter = AdvancedReports::DateRangeFilter.new(
      start_date: Date.new(2020, 4, 1),
      end_date: Date.new(2020, 6, 30)
    )
  end

  def create_entry(account:, amount:, date:, kind: "standard", **opts)
    account.entries.create!(
      name: "Test entry",
      date: date,
      amount: amount,
      currency: "USD",
      entryable: Transaction.new(kind: kind, **opts)
    )
  end

  test "returns monthly income expense and net cash flow totals" do
    create_entry(account: @account, amount: -3000, date: Date.new(2020, 4, 10))
    create_entry(account: @account, amount: 1200, date: Date.new(2020, 4, 12))
    create_entry(account: @account, amount: -2500, date: Date.new(2020, 5, 5))
    create_entry(account: @account, amount: 1600, date: Date.new(2020, 5, 8))

    result = AdvancedReports::IncomeExpensesQuery.new(@family, date_range_filter: @filter).call

    assert_equal 5500.to_d, result.total_income
    assert_equal 2800.to_d, result.total_expense
    assert_equal 2700.to_d, result.net_cash_flow
    assert_equal 49.09.to_d, result.savings_rate

    april = result.months.detect { |month| month.date == Date.new(2020, 4, 1) }
    may = result.months.detect { |month| month.date == Date.new(2020, 5, 1) }

    assert_equal 3000.to_d, april.income
    assert_equal 1200.to_d, april.expense
    assert_equal 1800.to_d, april.net_cash_flow

    assert_equal 2500.to_d, may.income
    assert_equal 1600.to_d, may.expense
    assert_equal 900.to_d, may.net_cash_flow
  end

  test "fills in months with no transactions" do
    create_entry(account: @account, amount: -3000, date: Date.new(2020, 4, 10))

    result = AdvancedReports::IncomeExpensesQuery.new(@family, date_range_filter: @filter).call

    assert_equal [ Date.new(2020, 4, 1), Date.new(2020, 5, 1), Date.new(2020, 6, 1) ], result.months.map(&:date)
    june = result.months.detect { |month| month.date == Date.new(2020, 6, 1) }

    assert_equal 0.to_d, june.income
    assert_equal 0.to_d, june.expense
    assert_equal 0.to_d, june.net_cash_flow
  end

  test "filters results to the selected account" do
    create_entry(account: @account, amount: -3000, date: TEST_DATE)
    create_entry(account: @other_account, amount: -5000, date: TEST_DATE)

    result = AdvancedReports::IncomeExpensesQuery.new(
      @family,
      date_range_filter: @filter,
      account_ids: @account.id
    ).call

    assert_equal 3000.to_d, result.total_income
  end

  test "returns zero savings rate when total income is zero" do
    create_entry(account: @account, amount: 1200, date: TEST_DATE)

    result = AdvancedReports::IncomeExpensesQuery.new(@family, date_range_filter: @filter).call

    assert_equal 0.to_d, result.total_income
    assert_equal(-1200.to_d, result.net_cash_flow)
    assert_equal 0.to_d, result.savings_rate
  end

  test "treats loan payments and investment contributions as expenses" do
    create_entry(account: @account, amount: -500, date: TEST_DATE, kind: "loan_payment")
    create_entry(account: @account, amount: -250, date: TEST_DATE, kind: "investment_contribution")

    result = AdvancedReports::IncomeExpensesQuery.new(@family, date_range_filter: @filter).call

    assert_equal 0.to_d, result.total_income
    assert_equal 750.to_d, result.total_expense
  end
end
