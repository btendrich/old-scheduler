class Answer
  attr_reader :note, :number

  def self.parse(body)
    new(body.to_s.strip)
  end

  def initialize(text)
    @text = text
    @note = nil
    @number = nil
    @kind = classify
  end

  def yes?
    @kind == :yes
  end

  def no?
    @kind == :no
  end

  def number?
    @kind == :number
  end

  private
    def classify
      bare = @text.sub(/[.!,]+\z/, "")
      return :yes if bare.match?(/\Ayes\z/i)
      return :no if bare.match?(/\Ano\z/i)

      if (digits = bare[/\A(\d+)\z/, 1])
        @number = digits.to_i
        return :number
      end

      if (match = @text.match(/\Ayes\b[.!,]*\s+(.+)\z/i))
        @note = match[1].strip
        return :yes
      end

      if (match = @text.match(/\Ano\b[.!,]*\s+(.+)\z/i))
        @note = match[1].strip
        return :no
      end

      if (match = @text.match(/\A(\d+)\b[.!,]*\s+(.+)\z/))
        @number = match[1].to_i
        @note = match[2].strip
        return :number
      end

      :other
    end
end
