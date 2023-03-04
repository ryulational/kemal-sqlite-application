module Kemal::Sqlite::Application
  VERSION = "0.1.0"
end

require "kemal"
require "sqlite3"

struct Category
  property id : Int32
  property name : String

  def initialize(@id : Int32, @name : String)
  end
end

struct Item
  property id : Int32
  property category : Int32
  property name : String

  def initialize(@id : Int32, @category : Int32, @name : String)
  end
end

struct Data
  property category : String
  property item : String

  def initialize(@category : String, @item : String)
  end
end

items = [Item.new(0, 0, "c"), Item.new(1, 0, "d"), Item.new(2, 1, "e")] of Item
categories = [Category.new(0, "a"), Category.new(1, "b")] of Category

violation_column_names = [] of String
violations = [] of String

db_path = File.expand_path("data.db")
if File.exists?(db_path)
  File.open(db_path).delete
end

DB.open "sqlite3://./data.db?foreign_keys=1" do |db|
  db.exec "create table categories (id integer primary key, name text not null)"
  db.exec "create table items (id integer primary key, category integer not null references categories (id), name text not null)"

  categories.each do |category|
    categories_args = [] of DB::Any
    categories_args << category.id
    categories_args << category.name
    db.exec "insert into categories values (?, ?)", args: categories_args
  end

  items.each do |item|
    items_args = [] of DB::Any
    items_args << item.id
    items_args << item.category
    items_args << item.name
    db.exec "insert into items values (?, ?, ?)", args: items_args
  end

  db.query("PRAGMA foreign_key_check") do |violation|
    violation_column_names << violation.column_name(0)
    violation_column_names << violation.column_name(1)
    violation_column_names << violation.column_name(2)
    violation_column_names << violation.column_name(3)

    violation.each do
      violations << "#{violation.read(String)} | #{violation.read(Int64)} | #{violation.read(String)} | #{violation.read(Int64)}"
    end
  end
end

if violations.size > 0
  vc = violation_column_names.join(" | ")
  v = violations.join("\n")
  puts "#{vc}\n#{v}"
  raise "Foreign key violation"
else
  puts "No foreign key violations"
end

get "/" do
  data_array = [] of Data

  DB.open "sqlite3://./data.db?foreign_keys=1" do |db|
    db.query "select items.name, categories.name from items left join categories on items.category = categories.id" do |rs|
      rs.each do
        data_array << Data.new(rs.read(String), rs.read(String))
      end
    end
  end

  items_categories = data_array
  render "src/views/index.ecr", "src/views/layouts/layout.ecr"
end

Kemal.run
