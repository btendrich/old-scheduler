class ListOrder
  # Rewrites the order column to match the given ids. A view sort never calls this.
  # Returns false when the ids are not exactly the records being ordered.
  def self.apply(records, ordered_ids, column)
    records = records.to_a
    ids = Array(ordered_ids).map(&:to_i)
    return false unless records.any? && ids.sort == records.map(&:id).sort

    values = records.map(&column).sort
    ApplicationRecord.transaction do
      ids.zip(values).each do |id, value|
        records.find { |record| record.id == id }.update!(column => value)
      end
    end
    true
  end
end
