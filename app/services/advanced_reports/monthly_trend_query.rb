class AdvancedReports::MonthlyTrendQuery < AdvancedReports::BaseQuery
  MODES = %w[expenses income both].freeze

  Result = Data.define(
    :currency,
    :months,
    :mode,
    :focus_metric,
    :month_over_month,
    :best_month,
    :worst_month,
    :average_value,
    :category_name
  )

  Month = Data.define(
    :date,
    :date_formatted,
    :label,
    :income,
    :expense,
    :rolling_income,
    :rolling_expense
  )

  SummaryValue = Data.define(:month, :value)
  MonthOverMonth = Data.define(:current_value, :previous_value, :change_amount, :change_percent)

  attr_reader :category_id, :mode, :selected_metric

  def initialize(family, date_range_filter:, account_ids: nil, category_id: nil, mode: "expenses")
    super(family, date_range_filter:, account_ids:)
    @category_id = category_id
    @mode = mode.presence_in(MODES) || "expenses"
    @selected_metric = @mode == "income" ? :income : :expense
  end

  def call
    monthly_rows = grouped_monthly_rows.index_by { |row| row.fetch("month").to_date }
    months = build_months(monthly_rows)
    focus_values = months.map(&selected_metric)

    Result.new(
      currency: family.currency,
      months: months,
      mode: mode,
      focus_metric: selected_metric,
      month_over_month: build_month_over_month(months),
      best_month: build_best_month(months, focus_values),
      worst_month: build_worst_month(months, focus_values),
      average_value: average_value(focus_values),
      category_name: selected_category_name
    )
  end

  private

    def grouped_monthly_rows
      ActiveRecord::Base.connection.select_all(query_sql).to_a
    end

    def query_sql
      transactions_scope = filtered_transactions_scope.where.not(kind: Transaction::BUDGET_EXCLUDED_KINDS)

      <<~SQL.squish
        SELECT
          DATE_TRUNC('month', e.date)::date AS month,
          SUM(#{income_sql}) AS total_income,
          SUM(#{expense_sql}) AS total_expense
        FROM (#{transactions_scope.to_sql}) t
        INNER JOIN entries e
          ON e.entryable_id = t.id
         AND e.entryable_type = 'Transaction'
        GROUP BY DATE_TRUNC('month', e.date)::date
        ORDER BY DATE_TRUNC('month', e.date)::date ASC
      SQL
    end

    def filtered_transactions_scope
      scope = scoped_transactions
      return scope if category_id.blank?

      scope.where(category_id:)
    end

    def income_sql
      <<~SQL.squish
        CASE
          WHEN t.kind IN ('investment_contribution', 'loan_payment') THEN 0
          WHEN e.amount < 0 THEN ABS(e.amount)
          ELSE 0
        END
      SQL
    end

    def expense_sql
      <<~SQL.squish
        CASE
          WHEN t.kind IN ('investment_contribution', 'loan_payment') THEN ABS(e.amount)
          WHEN e.amount > 0 THEN e.amount
          ELSE 0
        END
      SQL
    end

    def build_months(monthly_rows)
      incomes = []
      expenses = []

      each_month.map do |month_date|
        row = monthly_rows[month_date] || {}
        income = decimal_or_zero(row["total_income"])
        expense = decimal_or_zero(row["total_expense"])
        incomes << income
        expenses << expense

        Month.new(
          date: month_date,
          date_formatted: month_date.iso8601,
          label: month_date.strftime("%b %Y"),
          income: income,
          expense: expense,
          rolling_income: rolling_average(incomes),
          rolling_expense: rolling_average(expenses)
        )
      end
    end

    def each_month
      start_month = date_range_filter.start_date.beginning_of_month
      end_month = date_range_filter.end_date.beginning_of_month

      current_month = start_month
      months = []

      while current_month <= end_month
        months << current_month
        current_month = current_month.next_month
      end

      months
    end

    def rolling_average(values)
      recent_values = values.last(3)
      return 0.to_d if recent_values.empty?

      (recent_values.sum / recent_values.length).round(2)
    end

    def build_month_over_month(months)
      current_month = months.last
      previous_month = months[-2]
      current_value = current_month ? current_month.public_send(selected_metric) : 0.to_d
      previous_value = previous_month ? previous_month.public_send(selected_metric) : 0.to_d
      change_amount = current_value - previous_value

      MonthOverMonth.new(
        current_value: current_value,
        previous_value: previous_value,
        change_amount: change_amount,
        change_percent: percentage_change(previous_value, change_amount)
      )
    end

    def build_best_month(months, focus_values)
      pair = if selected_metric == :income
        months.zip(focus_values).max_by { |_month, value| value }
      else
        months.zip(focus_values).min_by { |_month, value| value }
      end

      SummaryValue.new(month: pair.first, value: pair.last)
    end

    def build_worst_month(months, focus_values)
      pair = if selected_metric == :income
        months.zip(focus_values).min_by { |_month, value| value }
      else
        months.zip(focus_values).max_by { |_month, value| value }
      end

      SummaryValue.new(month: pair.first, value: pair.last)
    end

    def average_value(focus_values)
      return 0.to_d if focus_values.empty?

      (focus_values.sum / focus_values.length).round(2)
    end

    def percentage_change(previous_value, change_amount)
      return nil if previous_value.zero?

      ((change_amount / previous_value) * 100).round(2)
    end

    def selected_category_name
      return nil if category_id.blank?

      family.categories.find_by(id: category_id)&.name_with_parent
    end

    def decimal_or_zero(value)
      value.present? ? value.to_d : 0.to_d
    end
end
