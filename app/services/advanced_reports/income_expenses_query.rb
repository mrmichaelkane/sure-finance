class AdvancedReports::IncomeExpensesQuery < AdvancedReports::BaseQuery
  Result = Data.define(
    :total_income,
    :total_expense,
    :net_cash_flow,
    :savings_rate,
    :currency,
    :months
  )

  Month = Data.define(
    :date,
    :label,
    :income,
    :expense,
    :net_cash_flow
  )

  def call
    monthly_rows = grouped_monthly_rows.index_by { |row| row.fetch("month").to_date }
    months = build_months(monthly_rows)

    total_income = months.sum(&:income)
    total_expense = months.sum(&:expense)
    net_cash_flow = total_income - total_expense

    Result.new(
      total_income: total_income,
      total_expense: total_expense,
      net_cash_flow: net_cash_flow,
      savings_rate: savings_rate(total_income, net_cash_flow),
      currency: family.currency,
      months: months
    )
  end

  private

    def grouped_monthly_rows
      ActiveRecord::Base.connection.select_all(query_sql).to_a
    end

    def query_sql
      transactions_scope = scoped_transactions.where.not(kind: Transaction::BUDGET_EXCLUDED_KINDS)

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
      each_month.map do |month_date|
        row = monthly_rows[month_date] || {}
        income = decimal_or_zero(row["total_income"])
        expense = decimal_or_zero(row["total_expense"])

        Month.new(
          date: month_date,
          label: month_date.strftime("%b %Y"),
          income: income,
          expense: expense,
          net_cash_flow: income - expense
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

    def savings_rate(total_income, net_cash_flow)
      return 0.to_d if total_income.zero?

      ((net_cash_flow / total_income) * 100).round(2)
    end

    def decimal_or_zero(value)
      value.present? ? value.to_d : 0.to_d
    end
end
