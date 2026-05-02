class AdvancedReports::DateRangeFilter
  PRESETS = %w[this_month last_3_months ytd last_year].freeze

  attr_reader :preset, :start_date, :end_date

  def initialize(preset: nil, start_date: nil, end_date: nil)
    if preset.present? && preset.to_s != "custom"
      @preset = preset.to_s
      @start_date, @end_date = resolve_preset(@preset)
    else
      @preset = "custom"
      @start_date = coerce_date(start_date)
      @end_date = coerce_date(end_date)
    end
  end

  def valid?
    start_date.is_a?(Date) && end_date.is_a?(Date) && start_date <= end_date
  end

  def date_range
    start_date..end_date
  end

  private

    def resolve_preset(key)
      case key
      when "this_month"
        [ Date.current.beginning_of_month, Date.current ]
      when "last_3_months"
        [ 3.months.ago.to_date.beginning_of_month, Date.current ]
      when "ytd"
        [ Date.current.beginning_of_year, Date.current ]
      when "last_year"
        [ 1.year.ago.to_date.beginning_of_year, 1.year.ago.to_date.end_of_year ]
      else
        raise ArgumentError, "Unknown preset: #{key}. Valid presets are: #{PRESETS.join(', ')}"
      end
    end

    def coerce_date(value)
      return value if value.is_a?(Date)
      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end
end
