require "test_helper"

class AdvancedReports::TransactionSummaryQueryTest < ActiveSupport::TestCase
  TEST_DATE = Date.new(2020, 6, 15)

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @filter = AdvancedReports::DateRangeFilter.new(
      start_date: TEST_DATE.beginning_of_month,
      end_date: TEST_DATE.end_of_month
    )
  end

  def create_entry(amount:, kind: "standard", **opts)
    @account.entries.create!(
      name: "Test entry",
      date: TEST_DATE,
      amount: amount,
      currency: "USD",
      entryable: Transaction.new(kind: kind, **opts)
    )
  end

  test "returns zero totals when no transactions exist in range" do
    result = AdvancedReports::TransactionSummaryQuery.new(@family, date_range_filter: @filter).call

    assert_equal 0, result.total_income
    assert_equal 0, result.total_expense
    assert_equal 0, result.net
  end

  test "calculates total expense from positive amounts" do
    create_entry(amount: 100)
    create_entry(amount: 50)

    result = AdvancedReports::TransactionSummaryQuery.new(@family, date_range_filter: @filter).call

    assert_equal 150.to_d, result.total_expense
    assert_equal 0, result.total_income
  end

  test "calculates total income from negative amounts" do
    create_entry(amount: -2000)
    create_entry(amount: -500)

    result = AdvancedReports::TransactionSummaryQuery.new(@family, date_range_filter: @filter).call

    assert_equal 2500.to_d, result.total_income
    assert_equal 0, result.total_expense
  end

  test "net equals income minus expense" do
    create_entry(amount: -3000)
    create_entry(amount: 1500)

    result = AdvancedReports::TransactionSummaryQuery.new(@family, date_range_filter: @filter).call

    assert_equal 3000.to_d, result.total_income
    assert_equal 1500.to_d, result.total_expense
    assert_equal 1500.to_d, result.net
  end

  test "excludes budget-excluded transaction kinds" do
    Transaction::BUDGET_EXCLUDED_KINDS.each do |kind|
      create_entry(amount: 500, kind: kind)
    end

    result = AdvancedReports::TransactionSummaryQuery.new(@family, date_range_filter: @filter).call

    assert_equal 0, result.total_expense
    assert_equal 0, result.total_income
  end

  test "classifies investment_contribution as expense regardless of sign" do
    create_entry(amount: -500, kind: "investment_contribution")

    result = AdvancedReports::TransactionSummaryQuery.new(@family, date_range_filter: @filter).call

    assert_equal 500.to_d, result.total_expense
    assert_equal 0, result.total_income
  end

  test "classifies loan_payment as expense regardless of sign" do
    create_entry(amount: -1200, kind: "loan_payment")

    result = AdvancedReports::TransactionSummaryQuery.new(@family, date_range_filter: @filter).call

    assert_equal 1200.to_d, result.total_expense
    assert_equal 0, result.total_income
  end

  test "excludes pending transactions from totals" do
    create_entry(amount: 999, extra: { "plaid" => { "pending" => true } })

    result = AdvancedReports::TransactionSummaryQuery.new(@family, date_range_filter: @filter).call

    assert_equal 0, result.total_expense
  end

  test "excludes transactions outside the date range" do
    @account.entries.create!(
      name: "Out of range",
      date: TEST_DATE - 2.months,
      amount: 500,
      currency: "USD",
      entryable: Transaction.new(kind: "standard")
    )

    result = AdvancedReports::TransactionSummaryQuery.new(@family, date_range_filter: @filter).call

    assert_equal 0, result.total_expense
  end

  test "result includes the family currency" do
    result = AdvancedReports::TransactionSummaryQuery.new(@family, date_range_filter: @filter).call

    assert_equal @family.currency, result.currency
  end

  test "scopes to the correct family only" do
    other_family = families(:empty)
    other_account = other_family.accounts.create!(
      name: "Other Checking",
      currency: "USD",
      accountable: Depository.create!,
      owner: users(:empty)
    )
    other_account.entries.create!(
      name: "Other family expense",
      date: TEST_DATE,
      amount: 500,
      currency: "USD",
      entryable: Transaction.new(kind: "standard")
    )

    result = AdvancedReports::TransactionSummaryQuery.new(@family, date_range_filter: @filter).call

    assert_equal 0, result.total_expense
  end
end
