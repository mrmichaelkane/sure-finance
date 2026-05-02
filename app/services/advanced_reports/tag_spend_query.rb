class AdvancedReports::TagSpendQuery < AdvancedReports::BaseQuery
  Result = Data.define(:currency, :rows, :comparison_rows)
  Row = Data.define(:tag_id, :tag_name, :total_spend, :transaction_count, :start_date, :end_date)

  attr_reader :compare_tag_ids

  def initialize(family, date_range_filter:, account_ids: nil, compare_tag_ids: [])
    super(family, date_range_filter:, account_ids:)
    @compare_tag_ids = Array(compare_tag_ids).compact_blank
  end

  def call
    rows = build_rows(indexed_rows)

    Result.new(
      currency: family.currency,
      rows: rows,
      comparison_rows: rows.select { |row| compare_tag_ids.include?(row.tag_id) }
    )
  end

  private

    def indexed_rows
      ActiveRecord::Base.connection.select_all(query_sql).to_a.index_by { |row| row.fetch("tag_id") }
    end

    def query_sql
      transactions_scope = scoped_transactions.where.not(kind: Transaction::BUDGET_EXCLUDED_KINDS)

      <<~SQL.squish
        SELECT
          tags.id AS tag_id,
          tags.name AS tag_name,
          SUM(#{expense_sql}) AS total_spend,
          COUNT(DISTINCT t.id) AS transaction_count,
          MIN(e.date) AS start_date,
          MAX(e.date) AS end_date
        FROM (#{transactions_scope.to_sql}) t
        INNER JOIN entries e
          ON e.entryable_id = t.id
         AND e.entryable_type = 'Transaction'
        INNER JOIN taggings
          ON taggings.taggable_id = t.id
         AND taggings.taggable_type = 'Transaction'
        INNER JOIN tags
          ON tags.id = taggings.tag_id
        GROUP BY tags.id, tags.name
        HAVING SUM(#{expense_sql}) > 0
        ORDER BY total_spend DESC, tags.name ASC
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

    def build_rows(row_lookup)
      row_lookup.values.map do |row|
        Row.new(
          tag_id: row.fetch("tag_id"),
          tag_name: row.fetch("tag_name"),
          total_spend: row.fetch("total_spend").to_d,
          transaction_count: row.fetch("transaction_count").to_i,
          start_date: row.fetch("start_date").to_date,
          end_date: row.fetch("end_date").to_date
        )
      end.sort_by { |row| [ -row.total_spend, row.tag_name ] }
    end
end
