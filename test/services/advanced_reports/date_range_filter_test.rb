require "test_helper"

class AdvancedReports::DateRangeFilterTest < ActiveSupport::TestCase
  test "this_month preset sets correct date range" do
    filter = AdvancedReports::DateRangeFilter.new(preset: "this_month")

    assert_equal Date.current.beginning_of_month, filter.start_date
    assert_equal Date.current, filter.end_date
    assert filter.valid?
  end

  test "last_3_months preset sets correct date range" do
    filter = AdvancedReports::DateRangeFilter.new(preset: "last_3_months")

    assert_equal 3.months.ago.to_date.beginning_of_month, filter.start_date
    assert_equal Date.current, filter.end_date
    assert filter.valid?
  end

  test "ytd preset sets correct date range" do
    filter = AdvancedReports::DateRangeFilter.new(preset: "ytd")

    assert_equal Date.current.beginning_of_year, filter.start_date
    assert_equal Date.current, filter.end_date
    assert filter.valid?
  end

  test "last_year preset sets correct date range" do
    filter = AdvancedReports::DateRangeFilter.new(preset: "last_year")

    assert_equal 1.year.ago.to_date.beginning_of_year, filter.start_date
    assert_equal 1.year.ago.to_date.end_of_year, filter.end_date
    assert filter.valid?
  end

  test "custom preset with valid dates" do
    filter = AdvancedReports::DateRangeFilter.new(
      preset: "custom",
      start_date: "2025-01-01",
      end_date: "2025-03-31"
    )

    assert_equal Date.new(2025, 1, 1), filter.start_date
    assert_equal Date.new(2025, 3, 31), filter.end_date
    assert_equal "custom", filter.preset
    assert filter.valid?
  end

  test "custom preset with Date objects" do
    start_date = Date.new(2025, 1, 1)
    end_date = Date.new(2025, 12, 31)

    filter = AdvancedReports::DateRangeFilter.new(start_date: start_date, end_date: end_date)

    assert_equal start_date, filter.start_date
    assert_equal end_date, filter.end_date
    assert filter.valid?
  end

  test "invalid when start_date after end_date" do
    filter = AdvancedReports::DateRangeFilter.new(
      start_date: "2025-12-31",
      end_date: "2025-01-01"
    )

    assert_not filter.valid?
  end

  test "invalid when custom dates are missing" do
    filter = AdvancedReports::DateRangeFilter.new(preset: "custom")

    assert_not filter.valid?
  end

  test "invalid when date strings are unparseable" do
    filter = AdvancedReports::DateRangeFilter.new(start_date: "not-a-date", end_date: "2025-12-31")

    assert_not filter.valid?
  end

  test "date_range returns a Range of start to end date" do
    filter = AdvancedReports::DateRangeFilter.new(preset: "ytd")

    assert_equal filter.start_date..filter.end_date, filter.date_range
  end

  test "unknown preset raises ArgumentError" do
    assert_raises(ArgumentError) do
      AdvancedReports::DateRangeFilter.new(preset: "last_decade")
    end
  end

  test "nil preset defaults to custom" do
    filter = AdvancedReports::DateRangeFilter.new(start_date: "2025-01-01", end_date: "2025-06-30")

    assert_equal "custom", filter.preset
  end
end
