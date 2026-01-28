#!/usr/bin/env ruby


# mode : PER_DIR = 1
#      : NORMAL = 1

require 'tz/debug2'

p > "~/hist_yk.debug"

class ZshHist
	HIST_FILE = File.expand_path("~/.zsh_history")
	HIST_DIR = File.expand_path("~/.zsh_history_pwd.d")
	ZSH_TO_CD = File.expand_path("~/.zsh_to_cd")
	class DirList
		List = []
		def self.emerge item
			i = List.rindex(item)
			if i != List.size - 1
				List.push item
				List.delete_at i if i
			end
		end
		def self.index item
			List.rindex item
		end
		def self.[] idx
			List[idx]
		end
	end
	class Item
		def set_param
			if @line =~ /\A:\s*(\d+):\s*(\d+);/
				@start = Time.at($1.to_i)
				@elapsed = $2.to_i
				@cmdline = $'.chomp
				@dir = IO.read(HIST_DIR + "/" + @hist_no.to_s).strip rescue nil
				DirList.emerge @dir if @dir && !@dir.empty?
			else
				@cmdline = @line.strip
				@dir = IO.read(HIST_DIR + "/" + @hist_no.to_s).strip rescue nil
				DirList.emerge @dir if @dir && !@dir.empty?
			end
		end
		%W{start elapsed dir}.each do |prop|
			class_eval %{
				def #{prop}
					set_param if !@#{prop}
					@#{prop}
				end
			}
		end
		def cmdline
			set_param if !@cmdline
			@buffer || @cmdline
		end
		attr_accessor :buffer
		def initialize ln, hist_no
			@line = ln
			@hist_no = hist_no
		end
	end
	def initialize
		@list = []
		@modified = {}
		reset_cursor
	end
	def reset_cursor
		@modified.each_key do |c|
			@list[c].buffer = nil
		end
		@modified.clear
		if @thread
			@killing = true
			@thread.join
			@thread = nil
			@killing = false
		end
		stat = File.stat(HIST_FILE)
		if @fId != [stat.ino, stat.dev] || @fLast > stat.size
			@fLast = stat.size
			@fId = [stat.ino, stat.dev]
			buff = IO.read HIST_FILE
			@list.clear
		elsif @fLast < stat.size
			File.open HIST_FILE do |fr|
				fr.seek @fLast
				buff = fr.read		
			end
		end
		if buff
			i = 0
			slst = buff.force_encoding("BINARY").split(/(?<!\\)\n/)
			slst.each do |s|
				i += 1
				@list.push Item.new(s, i)
			end
			@curPos = @list.size
			@thread = Thread.new do
				@list.each do |item|
					break if @killing
					item.set_param
				end
			end
		end
	end
	It = ZshHist.new
	def self.method_missing mth, *args
		It.method(mth).call *args
	end
	def get_hist direc, dmode, mmode, buffer, cursor, pwd
		head = buffer[0 ... (cursor.to_i rescue 0)]
		if @list[@curPos]
			if @list[@curPos].cmdline != buffer
				@list[@curPos].buffer = buffer
				@modified[@curPos] = true
			else
				@list[@curPos].buffer = nil
				@modified[@curPos] = false
			end
		else
			@buffer = buffer
		end
		case [direc, dmode]
		when ["BACK", "NORMAL"]
			if !head || head == ""
				@curPos -= 1 if @curPos > 0
			else
				i = @curPos
				begin
					i -= 1
					break if i < 0
				end while @list[i].cmdline[0...head.size] != head
				if i >= 0
					@curPos = i
				end
			end
		when ["BACK", "PER_DIR"]
			if @curPos > 0
				i = @curPos
				j = 0
				begin
					i -= 1
					break if i < 0
				end while @list[i].dir != (@list[@curPos]&.dir || pwd) || (head && head != @list[i].cmdline[0...head.size])
				if i != -1
					@curPos = i
				end
			end
		when ["FOR", "NORMAL"]
			if !head || head == ""
				@curPos += 1 if @curPos < @list.size
			else
				i = @curPos
				begin
					i += 1
					break if i >= @list.size
				end while @list[i].cmdline[0...head.size] != head
				if i != @list.size
					@curPos = i
				end
			end
		when ["FOR", "PER_DIR"]
			if @curPos == @list.size - 1 && @list[@curPos].dir == pwd
				@curPos = @list.size
			elsif @curPos != @list.size
				i = @curPos
				begin
					i += 1
					break if i >= @list.size
				end while @list[i].dir != (@list[@curPos]&.dir || pwd) || (head && head != @list[i].cmdline[0...head.size])
				if i != @list.size || ((@list[@curPos]&.dir || pwd) == pwd && (!head || head == ""))
					@curPos = i
				end
			end
		end
		if @curPos != @list.size
			if mmode == ""
				buf = @list[@curPos].cmdline.to_s
				ret = {"HISTNO" => @curPos.to_s, "BUFFER" => buf, "CURSOR" => buf.size }
			else
			end
		else
			ret = ":#{@buffer}"
		end
		p ret
		ret
	end
	def get_histdir direc, pwd
		DirList.emerge pwd
		if File.exist? ZSH_TO_CD
			dirCursor = IO.read(ZSH_TO_CD).strip
		else
			dirCursor = pwd
		end
		p dirCursor
		i = DirList.index dirCursor
		p i
		p DirList[i]
		p DirList[i - 1]
		if i
				dir = DirList[i + 	case direc
									when "BACK"
										-1
									when "FOR"
										1
									end
				]
		end
		if dir
			File.open ZSH_TO_CD, "w" do |fw|
				fw.write dir
			end
			p IO.read(ZSH_TO_CD)
			dir
		elsif direc == "BACK"
			dir = dirCursor
		else # direc = "FOR"
			dir = pwd
		end
		p dir
		dir
	end
end
def yk_hist direc, mode, head, pwd
 	ret = ZshHist::get_hist direc, mode, head, "", pwd
	ret
end
if File.expand_path($0) == File.expand_path(__FILE__)
	p yk_hist("BACK", "PER_DIR", ARGV[0], File.expand_path(Dir.pwd))
	p yk_hist("BACK", "PER_DIR", ARGV[0], File.expand_path(Dir.pwd))
	p yk_hist("BACK", "PER_DIR", ARGV[0], File.expand_path(Dir.pwd))
	p yk_hist("BACK", "PER_DIR", ARGV[0], File.expand_path(Dir.pwd))
	p yk_hist("BACK", "PER_DIR", ARGV[0], File.expand_path(Dir.pwd))
	p yk_hist("BACK", "PER_DIR", ARGV[0], File.expand_path(Dir.pwd))
	p yk_hist("FOR", "PER_DIR", ARGV[0], File.expand_path(Dir.pwd))
	p yk_hist("FOR", "PER_DIR", ARGV[0], File.expand_path(Dir.pwd))
	p yk_hist("FOR", "PER_DIR", ARGV[0], File.expand_path(Dir.pwd))
	p yk_hist("FOR", "PER_DIR", ARGV[0], File.expand_path(Dir.pwd))
	p yk_hist("FOR", "PER_DIR", ARGV[0], File.expand_path(Dir.pwd))
	p yk_hist("FOR", "PER_DIR", ARGV[0], File.expand_path(Dir.pwd))
	p yk_hist("FOR", "PER_DIR", ARGV[0], File.expand_path(Dir.pwd))
	p yk_hist("FOR", "PER_DIR", ARGV[0], File.expand_path(Dir.pwd))
end

