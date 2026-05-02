require "test_helper"

class AdvancedReports::BaseQueryTest < ActiveSupport::TestCase
  TEST_DATE = Date.new(2020, 6, 15)

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @filter = AdvancedReports::DateRangeFilter.new(
      start_date: TEST_DATE.beginning_of_month,
      end_date: TEST_DATE.end_of_month
    )
  end

  test "scopes transactions to the given family only" do
    other_family = families(:empty)
    other_account = other_family.accounts.create!(
      name: "Other Checking",
      currency: "USD",
      accountable: Depository.create!,
      owner: users(:empty)
    )
    other_entry = other_account.entries.create!(
      name: "Other family expense",
      date: TEST_DATE,
      amount: 999,
      currency: "USD",
      entryable: Transaction.new(kind: "standard")
    )

    family_entry = @account.entries.create!(
      name: "My expense",
      date: TEST_DATE,
      amount: 50,
      currency: "USD",
      entryable: Transaction.new(kind: "standard")
    )

    query = AdvancedReports::BaseQuery.new(@family, date_range_filter: @filter)
    transaction_ids = query.send(:scoped_transactions).pluck(:id)

    assert_includes transaction_ids, family_entry.entryable_id
    assert_not_includes transaction_ids, other_entry.entryable_id
  end

  test "filters transactions to the given date range" do
    in_range_entry = @account.entries.create!(
      name: "In range",
      date: TEST_DATE,
      amount: 25,
      currency: "USD",
      entryable: Transaction.new(kind: "standard")
    )

    out_of_range_entry = @account.entries.create!(
      name: "Out of range",
      date: TEST_DATE - 6.months,
      amount: 25,
      currency: "USD",
      entryable: Transaction.new(kind: "standard")
    )

    query = AdvancedReports::BaseQuery.new(@family, date_range_filter: @filter)
    transaction_ids = query.send(:scoped_transactions).pluck(:id)

    assert_includes transaction_ids, in_range_entry.entryable_id
    assert_not_includes transaction_ids, out_of_range_entry.entryable_id
  end

  test "excludes pending transactions" do
    pending_entry = @account.entries.create!(
      name: "Pending charge",
      date: TEST_DATE,
      amount: 30,
      currency: "USD",
      entryable: Transaction.new(kind: "standard", extra: { "simplefin" => { "pending" => true } })
    )

    query = AdvancedReports::BaseQuery.new(@family, date_range_filter: @filter)
    transaction_ids = query.send(:scoped_transactions).pluck(:id)

    assert_not_includes transaction_ids, pending_entry.entryable_id
  end
end
