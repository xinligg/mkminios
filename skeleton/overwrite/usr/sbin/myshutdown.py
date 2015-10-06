#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pygtk
pygtk.require('2.0')
import gtk
import gobject
import os, sys

class ProgressDialog:
	
    alarm_time = 10
	
    def setpoweroff(self, widget, data=None):
	os.system("poweroff &")

    def setreboot(self, widget, data=None):
        os.system("reboot &")

    def setcancel(self, widget, data=None):
        gtk.main_quit()

    def delete_event(self, widget, event, data=None):
        print "delete event occurred"
        return False

    def destroy(self, widget, data=None):
        gtk.main_quit()

    def __init__(self):
        self.window = gtk.Window(gtk.WINDOW_TOPLEVEL)
        self.window.set_position(gtk.WIN_POS_CENTER)
        self.window.connect("delete_event", self.delete_event)
        self.window.connect("destroy", self.destroy)

#        self.window.set_icon_from_file('/usr/share/pixmaps/staros-shutdown.png')
        self.window.set_title('关机')
        self.window.set_border_width(10)
        self.window.set_default_size(400, 200)

        self.button_poweroff = gtk.Button("关机")
        self.button_reboot = gtk.Button("重启")
        self.button_cancel = gtk.Button("取消")
        self.vbox = gtk.VBox()
        self.hbox = gtk.HBox()
        self.label_info = gtk.Label("是否确认关机？")
        self.label_progress = gtk.Label()

        self.hbox.set_spacing(20)


#		self.vbox.set_homogeneous()
        self.button_poweroff.connect("clicked", self.setpoweroff, None)
        self.button_reboot.connect("clicked", self.setreboot, None)
        self.button_cancel.connect("clicked", self.setcancel, None)
        self.label_progress.set_text("系统将会在10秒之后关机")
   
#        self.button_ok.connect_object("clicked", gtk.Widget.destroy, self.window)
#        self.button_cancel.connect_object("clicked", gtk.Widget.destroy, self.window)
   
        self.window.add(self.vbox)
        self.vbox.pack_start(self.label_info, True, True, 0)
        self.vbox.pack_start(self.label_progress, False, False, 0)
        self.hbox.pack_start(self.button_poweroff, True, True, 0)
        self.hbox.pack_start(self.button_reboot, True, True, 0)
        self.hbox.pack_start(self.button_cancel, True, True, 0)
#        self.hbox.add(self.button_poweroff)
#        self.hbox.add(self.button_reboot)
#        self.hbox.add(self.button_cancel)
        self.vbox.pack_start(self.hbox, False, True, 10)
    
        # The final step is to display this newly created widget.
#        self.button.show()
    
        # and the window
        self.window.show_all()
        
    def timeout (self):
		self.alarm_time = self.alarm_time - 1
		self.label_progress.set_text("系统将会在" + str(self.alarm_time) +"秒之后关机")
		if(self.alarm_time <= 0):
			os.system("poweroff &")
			return False
		return True

    def main(self):
        self.timeout_id = gobject.timeout_add(1000, self.timeout)
        gtk.main()

if __name__ == "__main__":
    app = ProgressDialog()
    app.main()

