class AdvancedReports::TransactionSummaryQuery < AdvancedReports::BaseQuery
  Result = Data.define(:total_income, :total_expense, :net, :currency)

  def call
    transactions_scope = scoped_transactions
      .where.not(kind: Transaction::BUDGET_EXCLUDED_KINDS)

    row = ActiveRecord::Base.connection.select_one(
      ActiveRecord::Base.sanitize_sql_array([ query_sql(transactions_scope), { excluded: false } ])
    )

    total_income = row["total_income"]&.to_d || 0
    total_expense = row["total_expense"]&.to_d || 0

    Result.new(
      total_income: total_income,
      total_expense: total_expense,
      net: total_income - total_expense,
      currency: family.currency
    )
  end

  private

    def query_sql(transactions_scope)
      <<~SQL
        SELECT
          SUM(CASE
            WHEN t.kind IN ('investment_contribution', 'loan_payment') THEN 0
            WHEN e.amount < 0 THEN ABS(e.amount)
            ELSE 0
          END) AS total_income,
          SUM(CASE
            WHEN t.kind IN ('investment_contribution', 'loan_payment') THEN ABS(e.amount)
            WHEN e.amount > 0 THEN e.amount
            ELSE 0
          END) AS total_expense
        FROM (#{transactions_scope.to_sql}) t
        JOIN entries e ON e.entryable_id = t.id AND e.entryable_type = 'Transaction'
        WHERE e.excluded = :excluded
      SQL
    end
end
