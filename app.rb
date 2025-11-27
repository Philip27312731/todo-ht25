require 'sinatra'
require 'sqlite3'
require 'slim'
require 'sinatra/reloader'





# Routen /
get '/' do
    slim(:index)
end

post('/todos/:id/delete') do 
id = params[:id].to_i 
db = SQLite3::Database.new('db/todos.db')
db.execute("DELETE FROM todos WHERE id = ?",id)
redirect('/todos')
end

post('/todos/:id/update') do 
  id = params[:id].to_i 
  name = params[:name]
  amount = params[:amount].to_i
  db = SQLite3::Database.new('db/todos.db')
  db.execute("UPDATE todos SET name=?,amount=? WHERE id=?", [name,amount,id])
  redirect('/todos')





end

get('/todos/:id/edit') do
 db = SQLite3::Database.new('db/todos.db') 
 db.results_as_hash = true
 id = params[:id].to_i
 @special_todo = db.execute("SELECT * FROM todos WHERE id = ?",id).first
 slim(:"todos/edit")
end

get('/todos/new') do
 slim(:"todos/new")
end


post('/todo') do # app.rb
 new_todo = params[:new_todo] # Hämta datan ifrån formuläret
 amount = params[:amount].to_i 
 db = SQLite3::Database.new('db/todos.db') # koppling till databasen
 db.execute("INSERT INTO todos (name, amount) VALUES (?,?)",[new_todo,amount])
 redirect('/todos') # Hoppa till routen som visar upp alla todoer
end



get('/todos')do

#Gör en koppling till db
db = SQLite3::Database.new("db/todos.db")

db.results_as_hash = true

#hämta allt från db 
datatodo = db.execute("SELECT * FROM todos")




querry = params[:q]

if querry && !querry.empty?
    @datatodo = db.execute("SELECT * FROM todos WHERE name LIKE ?","%#{querry}%")


else 
    @datatodo = db.execute("SELECT * FROM todos")

end 

#visa upp med slim
slim(:"todos/index")

end