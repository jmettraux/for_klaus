#--
# Copyright (c) 2012-2012, John Mettraux, jmettraux@gmail.com
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#++

$:.unshift(File.expand_path('..', __FILE__))

require 'pp'

require 'rufus-json/automatic'

require 'ruote'
require 'ruote/storage/fs_storage'

$stdout.sync = true


class Client

  def initialize

    @dboard = Ruote::Dashboard.new(
      Ruote::FsStorage.new('ruote_work'))

    print 'username: '; @user = gets.strip

    @workitem = nil

    run
  end

  protected

  def run

    loop do
      print("#{@user}" + (@workitem ? ":#{@workitem.fei.sid}" : '') + '> ')
      self.eval(gets)
    end
  end

  def eval(line)

    exit(0) if line == nil # control-d

    elts = line.split
    com = elts.shift
    command = "command_#{com}"

    if self.respond_to?(command)
      begin
        self.send(command, elts)
      rescue => e
        puts '-' * 80
        p e
        puts *e.backtrace
        puts '-' * 80
      end
    else
      puts "unkown command '#{com}'"
    end
  end

  def h_help; 'lists this help'; end

  def command_help(elts)

    methods.map(&:to_s).select { |m| m.match(/^h_/) }.sort.each do |hm|
      c = hm[2..-1]
      h = self.send(hm)
      printf("%14s: %s\n" % [ c, h ])
    end
  end

  def h_exit; 'exits this client'; end

  def command_exit(elts)

    exit(0)
  end

  def h_launch; 'launches the workflow in defs/def0.rb'; end

  def command_launch(elts)

    wfid = @dboard.launch('./defs/def0.rb')
    puts "launched process instance #{wfid}"
  end

  def h_ps; 'lists the currently running process instances'; end

  def command_ps(elts)

    printf(
      "%-36s  %4s %4s  %6s\n",
      *%w[ WFID EXPS ERRS FIELDS ])

    processes = @dboard.processes

    processes.each do |ps|

      printf(
        "%36s  %4d %4d  %s\n",
        ps.wfid,
        ps.expressions.size,
        ps.errors.size,
        ps.root_workitem ? ps.root_workitem.fields.inspect : '(none)')
    end
    puts "processes: #{processes.size}"
  end

  def h_workitems; 'lists the workitems available for the current user'; end

  def command_workitems(elts)

    user = elts.first || @user

    printf(
      "%3s %-36s %-14s %-21s\n",
      *%w[ N ID PARTICIPANT TASK ])

    workitems = @dboard.storage_participant.by_participant("user_#{user}")

    workitems.each_with_index do |wi, i|

      printf(
        "%3i %-36s %-14s %-21s\n",
        *[
          i,
          "#{wi.fei.wfid} #{wi.fei.expid}",
          wi.participant_name,
          wi.params['task']
        ])
    end

    puts "workitems: #{workitems.size}"
  end

  def h_workitem; 'select workitem n (from list of workitems)'; end

  def command_workitem(elts)

    n = (elts.first || -1).to_i

    @workitem = if n < 0
      nil
    else
      @dboard.storage_participant.by_participant("user_#{@user}")[n]
    end
  end

  def h_proceed; 'proceeds the current workitem'; end

  def command_proceed(elts)

    raise_unless_workitem

    @dboard.storage_participant.proceed(@workitem)

    @workitem = nil
  end

  def h_notes; 'print notes in current workitem'; end

  def command_notes(elts)

    raise_unless_workitem

    pp @workitem.fields['notes']
  end

  def h_note; 'take a "note" in the current workitem'; end

  def command_note(elts)

    raise_unless_workitem

    (@workitem.fields['notes'] ||= []) << elts.join(' ')

    @dboard.storage_participant.update(@workitem)

    @workitem = @dboard.storage_participant[@workitem.fei]
      # reload workitem
  end

  def h_user; 'change the current user'; end

  def command_user(elts)

    if u = elts.first
      @user = u
    else
      puts 'please pass a username'
    end
  end

  def raise_unless_workitem
    raise 'no workitems selected' unless @workitem
  end
end

Client.new

