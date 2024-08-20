/*
   This file is part of the package org-clock-dbus. It is subject to
   the license terms in the LICENSE file found in the top-level
   directory of this distribution and at:

     https://github.com/pjones/org-clock-dbus

   No part of this package, including this file, may be copied,
   modified, propagated, or distributed except according to the terms
   contained in the LICENSE file.
*/

use chrono::{DateTime, Local};
use dbus::blocking::Connection;
use dbus::message::{MatchRule, Message};
use std::sync::mpsc::{channel, Receiver, RecvTimeoutError, Sender};
use std::thread;
use std::time::{Duration, UNIX_EPOCH};

use crate::cli::MonitorArgs;
use crate::clock::{Clock, State};

pub fn monitor(args: MonitorArgs) -> Result<(), Box<dyn std::error::Error>> {
    let (tx, rx) = channel();
    let connection = Connection::new_session()?;

    let mut rule = MatchRule::new();
    rule.interface = Some("org.gnu.Emacs.Org.Clock".into());

    connection.add_match(rule, move |_: (), _, msg| {
        dispatch(&msg, &tx);
        true
    })?;

    thread::spawn(move || output(args, &rx));

    loop {
        connection.process(Duration::from_secs(60))?;
    }
}

fn dispatch(msg: &Message, tx: &Sender<State>) {
    let member = msg
        .member()
        .map(|m| m.to_string())
        .unwrap_or_else(|| String::from("Other"));

    match member.as_str() {
        "Started" => {
            let (arg0, arg1) = msg.get2();

            let started_at = arg0
                .map(|n| DateTime::from(UNIX_EPOCH + Duration::from_secs(n)))
                .unwrap_or_else(|| Local::now());

            let heading = arg1.unwrap_or_else(|| String::from("missing"));

            tx.send(State::Running {
                started_at,
                heading,
            })
            .unwrap();
        }
        "Stopped" => {
            tx.send(State::Stopped).unwrap();
        }
        _ => {
            println!("error: unexpected message: {:?}", msg);
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
