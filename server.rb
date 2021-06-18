require 'socket'

def main
  # internet (as apposed to local socket) means :INET
  # tcp (which is what http will go over require :STREAM
  socket = Socket.new(:INET, :STREAM)
  socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true) # lets us kill and restart the server without the kernal complaining that we're reusing the socket address
  socket.bind(Addrinfo.tcp("127.0.01", 9000))
  socket.listen(0) # number of incomming connections that can wait until the current one is finished
  conn_sock, addr_info = socket.accept

  conn = Connection.new(conn_sock)
  request = read_request(conn)
  respond_for_request(conn_sock, request)
  #respond(conn_sock, 200, "Some content..........................................")
end

class Connection
  def initialize(conn_sock)
    @conn_sock = conn_sock
    @buffer = ""
  end

  def read_line
    read_until("\r\n")
  end

  def read_until(string)
    until @buffer.include?(string)
      @buffer += @conn_sock.recv(7)
    end
    result, @buffer = @buffer.split(string, 2)
    result
  end
end

def read_request(conn)
  request_line= conn.read_line
  method, path, version = request_line.split(" ", 3)
  headers = {}
  loop do
    line = conn.read_line
    break if line.empty?
    key, value = line.split(/:\s*/, 2)
    headers[key] = value
  end
  Request.new(method, path, headers)
end

def respond_for_request(conn_sock, request)
  path = Dir.getwd + request.path # get the current directory of the server + the path from the request
  if File.exists?(path)
    if File.executable?(path)
      # this is similar to how cgi-bin works...
      content = `#{path}` # execute the path
    else
      content = File.read(path)
    end
    status_code = 200
  else
    content = ""
    status_code = 404
  end
  respond(conn_sock, status_code, content)
end

Request = Struct.new(:method, :path, :headers)

def respond(conn_sock, status_code, content)
  status_text = {
    200 => "OK",
    404 => "Not Found"
  }
  conn_sock.send("HTTP/1.1 #{status_code} #{status_text[status_code]}\r\n", 0)
  conn_sock.send("Content-Length: #{content.length}\r\n", 0)
  conn_sock.send("\r\n", 0)
  conn_sock.send(content, 0)
end

main
