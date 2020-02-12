require "nokogiri"
require "sqlite3"
#require_relative "./generateAccounts"

def add_competitors_to_db(db,date)
# open page, get rows
  page = File.open("../data/#{date}/#{date}_with_num.html") { |f| Nokogiri::XML(f) }
  rows = page.css("tr")
# drop the headers (in the first row), then iterate and input entries into db
  rows.drop(1).each do |row|
     entry = row.css("td")
     last = entry[0].child.text if entry[0].child
     first = entry[1].child.text if entry[1].child
     c_id = entry[2].child.text.to_i if entry[2].child
     db.execute " INSERT OR IGNORE INTO Competitors( 
                      CompetitorId,
                      Name_First,
                      Name_Last )
                  VALUES (
                      :competitor_id, 
                      :first, 
                      :last);",c_id,first,last
  end

end # add_competitors_to_db

def add_competitors_affiliation(db,date)
  page = File.open("../data/#{date}/#{date}_by_school.html") { |f| Nokogiri::XML(f) }
  rows = page.css("tr")
# drop the headers (in the first row), then iterate and input affiliation into db
  rows.drop(1).each do |row|
    entry = row.css("td")
    # only do this if there's an actual affiliation claimed
    if entry[0].child
      school = entry[0].child.text
      if entry[1].child
        name = entry[1].child.text.sub(/\W*Pass:.*/, '') 
        db.execute "UPDATE Competitors SET claimed_affiliation = :school WHERE Name_First || ' ' || Name_Last = :name;", school, name 
      end
    end

  end
  
end

def add_acct_number(db,date)
  page = File.open("../data/#{date}/#{date}_entry_count_total.html") { |f| Nokogiri::XML(f) }
  rows = page.css("tr")
# drop the headers (in the first row), then iterate and input affiliation into db
  rows.drop(1).each do |row|
    entry = row.css("td")
    acct_num = entry[0].child.text.to_i
    name = entry[1].child.text.sub(", ", "^-^") 
    db.execute "UPDATE Competitors SET Acct_number  = :acct_num WHERE ifnull(Name_Last,'') || '^-^' || ifnull(Name_First,'') = :name;", acct_num, name 
  end
end
 
  

begin
#  dates=["23-10","30-10","31-10","07-11","14-11","18-11","19-11","20-11","22-11", "25-11", "27-11", "28-11", "30-11"]
#  dates=["23-10","07-11"]
   dates = File.open("../data/Dates")
# open db
  db = SQLite3::Database.open "data.db"
  registration_cutoffs = "Note that the format of dates is dd-mm as opposed to mm-dd \n"
# this following line is for dev only. delete it after! TODO
#  db.execute "DROP TABLE IF EXISTS Competitors;"
  db.execute "CREATE TABLE IF NOT EXISTS Competitors(
                                                  CompetitorId INTEGER PRIMARY KEY, 
                                                  Name_First TEXT, 
                                                  Name_Last TEXT, 
                                                  Claimed_affiliation TEXT,
                                                  Number_on_back INT,
                                                  Acct_number INT,
                                                  Type_of_registration TEXT,
                                                  Due INTEGER,
                                                  Paid_by TEXT,
                                                  Amount_paid TEXT,
                                                  Checks BOOLEAN,
                                                  Cash BOOLEAN,
                                                  Notes TEXT
                                                  );"
  #db.execute "CREATE TABLE IF NOT EXISTS Accounts(AccountId INTEGER PRIMARY KEY, Name_First TEXT, Name_Last TEXT, Address TEXT, City TEXT, State TEXT, Country TEXT, Zip TEXT, Email TEXT, Phone TEXT);"
  #add_competitors_to_db(db,date)
  #add_accounts_to_db(db)
  #add_account_details_to_db(db)
  #add_competitors_affiliation(db,date)

  dates.each do |date|
    date = date.chomp().strip()
    next if date.empty?
    puts date
    add_competitors_to_db(db,date)
    add_competitors_affiliation(db,date)
    add_acct_number(db,date)
    latest_id = (db.execute "SELECT MAX(CompetitorId) FROM Competitors;")[0][0]
    latest_name = (db.execute "SELECT Name_First, Name_Last FROM Competitors WHERE CompetitorId = #{latest_id};").join(", ")
    registration_cutoffs = "#{registration_cutoffs} \n latest competitor registered by #{date} has id = #{latest_id} (#{latest_name})"
  end


rescue SQLite3::Exception => e
  puts "Ooops. Problems:"
  puts e
  puts "___________________________________________"
  puts e.backtrace

ensure
  db.close if db

end
puts registration_cutoffs
File.open("registration_cutoffs.txt", 'w') { |file| file.write( registration_cutoffs) }
puts "done"
