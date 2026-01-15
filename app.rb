require 'sinatra'
require 'sqlite3'
require 'slim'
require 'sinatra/reloader' if development?

# Konfigurera Sinatra för att hitta statiska filer
set :public_folder, 'public'

enable :sessions


#Körs ifrån ett formulär
post('/login') do
 nameAndSecret = [params[:namn],params[:password]]
 session[:things] = nameAndSecret #Sparas i session
 redirect('/result')#Posten skickas till Geten!
end

get('/result') do
 slim(:result) 
end

#Länk som tömmer session (blir 'nil')
get('/clear_session) do
 session.clear
 slim(:login)
end


# Databashjälpare
def db
  database = SQLite3::Database.new('db/todos.db')
  database.results_as_hash = true
  database
end

# Initialisera databasen
def init_db
  database = db
  database.execute <<-SQL
    CREATE TABLE IF NOT EXISTS todos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      amount INTEGER DEFAULT 0,
      category TEXT DEFAULT 'privat',
      completed INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
  SQL
  database.close
end

# Kör vid start
begin
  init_db
rescue => e
  puts "Database initialization warning: #{e.message}"
end

# Startsida
get '/' do
  slim(:index)
end

# Visa alla todos
get '/todos' do
  database = db
  
  query = params[:q]
  
  if query && !query.empty?
    @datatodo = database.execute(
      "SELECT * FROM todos WHERE name LIKE ? ORDER BY completed ASC, created_at DESC",
      "%#{query}%"
    )
  else
    @datatodo = database.execute(
      "SELECT * FROM todos ORDER BY completed ASC, created_at DESC"
    )
  end
  
  slim(:"todos/index")
end

# Visa formulär för ny todo
get '/todos/new' do
  slim(:"todos/new")
end

# Skapa ny todo
post '/todos' do
  name = params[:new_todo]
  description = params[:description]
  amount = params[:amount].to_i
  category = params[:category] || 'privat'
  
  database = db
  database.execute(
    "INSERT INTO todos (name, description, amount, category) VALUES (?, ?, ?, ?)",
    [name, description, amount, category]
  )
  
  redirect('/todos')
end

# Visa redigeringsformulär
get '/todos/:id/edit' do
  database = db
  id = params[:id].to_i
  
  @special_todo = database.execute(
    "SELECT * FROM todos WHERE id = ?",
    id
  ).first
  
  slim(:"todos/edit")
end

# Uppdatera todo
post '/todos/:id/update' do
  id = params[:id].to_i
  name = params[:name]
  description = params[:description]
  amount = params[:amount].to_i
  category = params[:category] || 'privat'
  
  database = db
  database.execute(
    "UPDATE todos SET name=?, description=?, amount=?, category=? WHERE id=?",
    [name, description, amount, category, id]
  )
  
  redirect('/todos')
end

# Markera som färdig/inte färdig
post '/todos/:id/toggle' do
  id = params[:id].to_i
  
  database = db
  
  # Hämta nuvarande status
  todo = database.execute("SELECT completed FROM todos WHERE id = ?", id).first
  new_status = todo["completed"] == 1 ? 0 : 1
  
  # Uppdatera status
  database.execute("UPDATE todos SET completed = ? WHERE id = ?", [new_status, id])
  
  redirect('/todos')
end

# Ta bort todo
post '/todos/:id/delete' do
  id = params[:id].to_i
  
  database = db
  database.execute("DELETE FROM todos WHERE id = ?", id)
  
  redirect('/todos')
end

# Rensa alla färdiga todos
post '/todos/clear_completed' do
  database = db
  database.execute("DELETE FROM todos WHERE completed = 1")
  
  redirect('/todos')
end