class AdvancedReports::BaseQuery
  attr_reader :family, :date_range_filter, :account_ids

  def initialize(family, date_range_filter:, account_ids: nil)
    @family = family
    @date_range_filter = date_range_filter
    @account_ids = Array(account_ids).compact_blank
  end

  private

    def scoped_transactions
      scope = family.transactions
        .visible
        .excluding_pending
        .in_period(date_range_filter)
        .joins(:entry)
        .where(entries: { excluded: false })

      return scope if account_ids.empty?

      scope.where(entries: { account_id: account_ids })
    end
end
