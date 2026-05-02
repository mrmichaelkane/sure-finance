class AdvancedReports::BaseQuery
  attr_reader :family, :date_range_filter

  def initialize(family, date_range_filter:)
    @family = family
    @date_range_filter = date_range_filter
  end

  private

    def scoped_transactions
      family.transactions
        .visible
        .excluding_pending
        .in_period(date_range_filter)
    end
end
