require "test_helper"

class AdvancedReports::TagSpendQueryTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @other_account = accounts(:connected)
    @tag_one = tags(:one)
    @tag_two = tags(:two)
    @tag_three = tags(:three)
    @filter = AdvancedReports::DateRangeFilter.new(
      start_date: Date.new(2020, 4, 1),
      end_date: Date.new(2020, 6, 30)
    )
  end

  def create_entry(account:, amount:, date:, tags:, kind: "standard")
    account.entries.create!(
      name: "Tagged transaction",
      date: date,
      amount: amount,
      currency: "USD",
      entryable: Transaction.new(kind: kind, tags: tags)
    )
  end

  test "returns all tags with spending in the period" do
    create_entry(account: @account, amount: 100, date: Date.new(2020, 4, 10), tags: [ @tag_one ])
    create_entry(account: @account, amount: 200, date: Date.new(2020, 5, 10), tags: [ @tag_two ])

    result = AdvancedReports::TagSpendQuery.new(@family, date_range_filter: @filter).call

    assert_equal [ @tag_two.id, @tag_one.id ], result.rows.map(&:tag_id)
  end

  test "counts multi tagged transactions under each tag" do
    create_entry(account: @account, amount: 120, date: Date.new(2020, 4, 10), tags: [ @tag_one, @tag_two ])

    result = AdvancedReports::TagSpendQuery.new(@family, date_range_filter: @filter).call

    one_row = result.rows.detect { |row| row.tag_id == @tag_one.id }
    two_row = result.rows.detect { |row| row.tag_id == @tag_two.id }

    assert_equal 120.to_d, one_row.total_spend
    assert_equal 120.to_d, two_row.total_spend
    assert_equal 1, one_row.transaction_count
    assert_equal 1, two_row.transaction_count
  end

  test "excludes tags with zero transactions in the period" do
    create_entry(account: @account, amount: 120, date: Date.new(2020, 4, 10), tags: [ @tag_one ])

    result = AdvancedReports::TagSpendQuery.new(@family, date_range_filter: @filter).call

    assert_not_includes result.rows.map(&:tag_id), @tag_three.id
  end

  test "supports click through comparison selection" do
    create_entry(account: @account, amount: 120, date: Date.new(2020, 4, 10), tags: [ @tag_one ])
    create_entry(account: @account, amount: 200, date: Date.new(2020, 5, 10), tags: [ @tag_two ])

    result = AdvancedReports::TagSpendQuery.new(
      @family,
      date_range_filter: @filter,
      compare_tag_ids: [ @tag_one.id, @tag_two.id ]
    ).call

    assert_equal [ @tag_two.id, @tag_one.id ], result.comparison_rows.map(&:tag_id)
  end

  test "filters by selected account ids" do
    create_entry(account: @account, amount: 120, date: Date.new(2020, 4, 10), tags: [ @tag_one ])
    create_entry(account: @other_account, amount: 400, date: Date.new(2020, 4, 12), tags: [ @tag_one ])

    result = AdvancedReports::TagSpendQuery.new(
      @family,
      date_range_filter: @filter,
      account_ids: @account.id
    ).call

    row = result.rows.detect { |item| item.tag_id == @tag_one.id }
    assert_equal 120.to_d, row.total_spend
  end
end
