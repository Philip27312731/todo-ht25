require 'sinatra'
require 'sqlite3'
require 'slim'
require 'bcrypt'
require 'sinatra/reloader' if development?

# Konfigurera Sinatra för att hitta statiska filer
set :public_folder, 'public'

enable :sessions

# Middleware för att kontrollera inloggning för skyddade rutter
def require_login
  unless session[:user_id]
    redirect('/login')
  end
end

get('/login') do
  slim(:login)
end

get('/register') do
  slim(:'todos/register')
end

#Körs ifrån ett formulär
post('/login') do
  username = params[:namn].to_s.strip
  password = params[:password].to_s.strip
  
  if username.empty? || password.empty?
    @error = "Username and password are required"
    return slim(:login)
  end
  
  database = db
  begin
    user = database.execute(
      "SELECT id, password_hash FROM users WHERE username = ?",
      [username]
    ).first
    
    if user.nil?
      @error = "Ogiltigt användarnamn eller lösenord"
      return slim(:login)
    end
    
    if BCrypt::Password.new(user['password_hash']) == password
      session[:user_id] = user['id']
      session[:username] = username
      redirect('/todos')
    else
      @error = "Ogiltigt användarnamn eller lösenord"
      slim(:login)
    end
  ensure
    database.close
  end
end

post('/register') do
  username = params[:username].to_s.strip
  password = params[:password].to_s.strip
  confirm_password = params[:confirm_password].to_s.strip
  
  if username.empty? || password.empty? || confirm_password.empty?
    @error = "Alla fält är obligatoriska"
    return slim(:'todos/register')
  end
  
  if password != confirm_password
    @error = "Lösenorden matchar inte"
    return slim(:'todos/register')
  end
  
  if password.length < 3
    @error = "Lösenordet måste vara minst 3 tecken"
    return slim(:'todos/register')
  end
  
  database = db
  begin
    password_hash = BCrypt::Password.create(password)
    database.execute(
      "INSERT INTO users (username, password_hash) VALUES (?, ?)",
      [username, password_hash]
    )
    session[:user_id] = database.last_insert_row_id
    session[:username] = username
    redirect('/todos')
  rescue SQLite3::ConstraintException
    @error = "Användarnamnet är redan registrerat"
    slim(:'todos/register')
  ensure
    database.close
  end
end

#Länk som tömmer session (blir 'nil')
get('/clear_session') do
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
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
  SQL
  database.execute <<-SQL
    CREATE TABLE IF NOT EXISTS todos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      name TEXT NOT NULL,
      description TEXT,
      amount INTEGER DEFAULT 0,
      category TEXT DEFAULT 'privat',
      completed INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY(user_id) REFERENCES users(id)
    );
  SQL
  database.close
end

# Kör vid start
begin
  init_db
rescue => e
  puts "Varning vid databasinitialisering: #{e.message}"
end

# Startsida
get '/' do
  slim(:index)
end

# Visa alla todos
get '/todos' do
  require_login
  database = db
  
  query = params[:q]
  
  if query && !query.empty?
    @datatodo = database.execute(
      "SELECT * FROM todos WHERE user_id = ? AND name LIKE ? ORDER BY completed ASC, created_at DESC",
      [session[:user_id], "%#{query}%"]
    )
  else
    @datatodo = database.execute(
      "SELECT * FROM todos WHERE user_id = ? ORDER BY completed ASC, created_at DESC",
      [session[:user_id]]
    )
  end
  
  slim(:"todos/index")
end

# Visa formulär för ny todo
get '/todos/new' do
  require_login
  slim(:'todos/new')
end

# Skapa ny todo
post '/todos' do
  require_login
  name = params[:new_todo]
  description = params[:description]
  amount = params[:amount].to_i
  category = params[:category] || 'privat'
  
  database = db
  database.execute(
    "INSERT INTO todos (user_id, name, description, amount, category) VALUES (?, ?, ?, ?, ?)",
    [session[:user_id], name, description, amount, category]
  )
  
  redirect('/todos')
end

# Visa redigeringsformulär
get '/todos/:id/edit' do
  require_login
  database = db
  id = params[:id].to_i
  
  @special_todo = database.execute(
    "SELECT * FROM todos WHERE id = ? AND user_id = ?",
    [id, session[:user_id]]
  ).first
  
  slim(:'todos/edit')
end

# Uppdatera todo
post '/todos/:id/update' do
  require_login
  id = params[:id].to_i
  name = params[:name]
  description = params[:description]
  amount = params[:amount].to_i
  category = params[:category] || 'privat'
  
  database = db
  database.execute(
    "UPDATE todos SET name=?, description=?, amount=?, category=? WHERE id=? AND user_id=?",
    [name, description, amount, category, id, session[:user_id]]
  )
  
  redirect('/todos')
end

# Markera som färdig/inte färdig
post '/todos/:id/toggle' do
  require_login
  id = params[:id].to_i
  
  database = db
  
  # Hämta nuvarande status
  todo = database.execute("SELECT completed FROM todos WHERE id = ? AND user_id = ?", [id, session[:user_id]]).first
  new_status = todo["completed"] == 1 ? 0 : 1
  
  # Uppdatera status
  database.execute("UPDATE todos SET completed = ? WHERE id = ? AND user_id = ?", [new_status, id, session[:user_id]])
  
  redirect('/todos')
end

# Ta bort todo
post '/todos/:id/delete' do
  require_login
  id = params[:id].to_i
  
  database = db
  database.execute("DELETE FROM todos WHERE id = ? AND user_id = ?", [id, session[:user_id]])
  
  redirect('/todos')
end

# Rensa alla färdiga todos
post '/todos/clear_completed' do
  require_login
  database = db
  database.execute("DELETE FROM todos WHERE completed = 1 AND user_id = ?", [session[:user_id]])
  
  redirect('/todos')
end