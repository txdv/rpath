
class RPath
	attr_accessor :parent, :child, :method, :args, :block

	def initialize(parent = nil, method = nil, args = nil, block = nil)
		@parent = parent
		@method = method
		@args = args
		@block = block
		parent.child = self unless parent.nil?
	end

	def is_root?
		parent == nil
	end

	def method_missing(method, *args, &block)
		RPath.new(self, method, args, block)
	end

	def root
		return self if is_root?
		return self.parent.root
	end

	def self.method_missing(method, *args, &block)
		return RPath.new(nil, method, args, block)
	end

	def to_xpath
		xpath = []
		node = root
		while not node.nil?
			case node.method
			when :[]
				xpath[xpath.size - 1] = xpath.last + "[#{node.args[0]}]"
			else
				xpath.push node.method.to_s
			end
			node = node.child
		end
		return xpath.join("/")
	end
end

def delete(obj, path, recursive = false)
	path = path.root unless recursive
	if obj.is_a?(Array)
		case path.method
		when :[]
			if path.args.size == 0
				if path.block.nil?
					if path.child.nil?
						i = obj.size - 1
						while i >= 0 do
							obj.delete_at(i)
							i -= 1
						end
					else
						obj.each { |e| delete(e, path.child, true) }
					end
				else
					i = obj.size - 1
					while i >= 0 do
						if path.block.call(i)
							if path.child.nil?
								obj.delete_at(i)
							else
								delete(obj, path.child, true)
							end
						end
						i -= 1
					end
				end
			elsif path.args.size == 1
				val = path.args[0]
				if path.child.nil?
					if val.is_a?(Fixnum)
						obj.delete_at(path.args[0])
					elsif val.is_a?(Proc)
						i = obj.size - 1
						while i >= 0 do
							if val.call(i)
								if path.child.nil?
									obj.delete_at(i)
								else
									delete(obj, path.child, true)
								end
							end
							i -= 1
						end
					else
						throw "not supported #{val.class}"
					end
				else
					if val.is_a?(Fixnum)
						delete(obj[val], path.child, true)
					elsif val.is_a?(Range)
						max = [val.end, obj.size].min
						min = [0, val.begin].max
						(min..max).each { |i| delete(obj[i], path.child, true) }
					else
						throw "not supported #{val.class}"
					end
				end
			else
				arr = path.args.collect { |i| i.class }.uniq
				if arr.size == 1 and arr.first == Fixnum
					path.args.reject { |i| i < 0 || i > obj.size }.sort_by { |i| -i }.each { |i| obj.delete_at(i) }
				else
					throw "not supported"
				end
			end
		end
	elsif obj.is_a?(Hash)
		case path.method
		when :[]
			if path.args.size == 1
				val = path.args[0]
				if path.child.nil?
					obj.delete(val)
				else
					delete(obj[val], path.child, true)
				end
			end
		else
			if obj.include?(path.method)
				if path.child.nil?
					obj.delete(path.method)
				else
					delete(obj[path.method], path.child, true)
				end
			else
				puts "ASD"
			end
		end
	end
	return obj
end

if __FILE__ == $0
	arr = [
		{ :name => "John" },
		{ :name => "Jack" },
		{ :test => "test" },
		{ :test => "test2" }
	]

	def clone(obj)
		Marshal.load(Marshal.dump(obj))
	end

	p delete(clone(arr), RPath[][:name, :test])
	p delete(clone(arr), RPath[0][:name])
	p delete(clone(arr), RPath[][:name])
	p delete(clone(arr), RPath[1..2][:name])
	p delete(clone(arr), RPath[0, 2])
	p delete(clone(arr), RPath[&lambda { |i| i % 2 == 0 }])
	p delete(clone(arr), RPath[-> (i) { i % 2 == 0 }])

	lam = lambda { |i| i % 2 == 0 }
	p delete(clone(arr), RPath[lam])

	p delete({ :test => { :abc => 2 } }, RPath[:test][:abc])
	p delete({ :test => { :abc => 2 } }, RPath.test)
	p delete({ :test => { :abc => 2 } }, RPath.test.abc)
	p delete({ "test" => { "abc" => 2 } }, RPath["test"]["abc"])
	p delete({ "test" => { "abc" => 2 } }, RPath["test"])

	p delete({ :test => [1, 2, 3] }, RPath[:test][])


	#puts delete(["a", "b", "c"], Path[["a", "b"]])

<<OUTPUT
	[{}, {:name=>"Jack"}, {:test=>"test"}, {:test=>"test2"}]
	[{}, {}, {:test=>"test"}, {:test=>"test2"}]
	[{:name=>"John"}, {}, {:test=>"test"}, {:test=>"test2"}]
	[{:name=>"Jack"}, {:test=>"test2"}]
	[{:name=>"Jack"}, {:test=>"test2"}]
	[{:name=>"Jack"}, {:test=>"test2"}]
	[{:name=>"Jack"}, {:test=>"test2"}]
	{:test=>{}}
	{}
	{:test=>{}}
	{"test"=>{}}
OUTPUT

	p RPath.booklist.books[1].test.to_xpath
	p RPath.booklist.books { |x| x.price > 2 }.to_xpath

<<OUTPUT
	"booklist/books[1]/test"
OUTPUT

end
