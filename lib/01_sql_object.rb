require 'byebug'
require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    unless @columns
      db = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        #{table_name}
      SQL
      columns = db.first
      @columns = columns.map(&:to_sym)
    end
    @columns
  end

  def self.finalize!
    columns.each do |column|
      define_method("#{column}") do
        attributes[column]
      end
      define_method("#{column}=") do |value|
        attributes[column] = value
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= self.name.tableize
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
    SELECT *
    FROM #{table_name}
    SQL
    parse_all(results)
  end

  def self.parse_all(results)
    new_objects = []
    results.each do |result|
      new_objects << self.new(result)
    end
    new_objects
  end

  def self.find(id)
    results = DBConnection.execute(<<-SQL, id)
    SELECT *
    FROM #{table_name}
    WHERE id = ?
    SQL
    return self.new(results.first) unless results.empty?
    return nil
  end

  def initialize(params = {})
    params.each do |attr_name, val|
      unless self.class.columns.include?(attr_name.to_sym)
        raise "unknown attribute '#{attr_name}'"
      end
      send("#{attr_name}=", val)
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map { |column| self.attributes[column] }
  end

  def insert
    col_names = self.class.columns.join(",")
    question_marks = (["?"] * self.class.columns.size).join(",")

    DBConnection.execute(<<-SQL, *attribute_values)
    INSERT INTO #{self.class.table_name} (#{col_names})
    VALUES (#{question_marks})
    SQL
    self.id = DBConnection.last_insert_row_id
  end

  def update
    col_names = self.class.columns.map { |column| "#{column.to_s} = ?"}.join(",")

    DBConnection.execute(<<-SQL, *attribute_values, id)
    UPDATE #{self.class.table_name}
    SET #{col_names}
    WHERE id = ?
    SQL
  end

  def save
    if self.id.nil?
      insert
    else
      update
    end
  end
end
