/*
   This file is part of the package org-clock-dbus. It is subject to
   the license terms in the LICENSE file found in the top-level
   directory of this distribution and at:

     https://github.com/pjones/org-clock-dbus

   No part of this package, including this file, may be copied,
   modified, propagated, or distributed except according to the terms
   contained in the LICENSE file.
*/

use dbus::message::Message;
use std::error::Error;
use std::sync::mpsc::{channel, Receiver, RecvTimeoutError, Sender};
use std::thread;
use std::time::Duration;

use crate::cli::MonitorArgs;
use crate::clock::{Clock, State};
use crate::dbus::DBusHelper;

pub fn monitor(args: MonitorArgs) -> Result<(), Box<dyn Error>> {
    let (tx, rx) = channel();
    let helper = DBusHelper::new()?;

    thread::spawn(move || output(args, &rx));

    if let Ok(starting) = helper.get_starting_state() {
        tx.send(starting)?;
    }

    helper.on_prop_changed(move |msg| {
        dispatch(&msg, &tx);
        true
    });

    helper.event_loop();
    Ok(())
}

fn dispatch(msg: &Message, tx: &Sender<State>) {
    let member = msg
        .member()
        .map(|m| m.to_string())
        .unwrap_or_else(|| String::from("Other"));

    match member.as_str() {
        "PropertiesChanged" => {
            if let Some(state) = DBusHelper::decode_prop_change_message(msg) {
                tx.send(state).unwrap();
            }
        }
        _ => {
            println!("error: unexpected message ({:?}): {:?}", member, msg);
        }
    }
}

fn output(args: MonitorArgs, rx: &Receiver<State>) {
    let mut clock = Clock::new(args);

    loop {
        clock.output();

        match rx.recv_timeout(Duration::from_secs(60)) {
            Ok(new_state) => {
                clock.state = new_state;
            }
            Err(RecvTimeoutError::Timeout) => {
                continue;
            }
            Err(RecvTimeoutError::Disconnected) => {
                break;
            }
        }
    }
}
