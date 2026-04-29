/*
   This file is part of the package org-clock-dbus. It is subject to
   the license terms in the LICENSE file found in the top-level
   directory of this distribution and at:

     https://github.com/pjones/org-clock-dbus

   No part of this package, including this file, may be copied,
   modified, propagated, or distributed except according to the terms
   contained in the LICENSE file.
*/

use chrono::DateTime;
use dbus::blocking::{BlockingSender, Connection};
use dbus::message::{MatchRule, Message};
use std::error::Error;
use std::time::{Duration, UNIX_EPOCH};

use crate::clock::State;

pub struct DBusHelper {
    connection: Connection,
}

impl DBusHelper {
    pub fn new() -> Result<DBusHelper, Box<dyn Error>> {
        let connection = Connection::new_session()?;
        let helper = DBusHelper { connection };
        Ok(helper)
    }

    pub fn on_prop_changed<F>(&self, mut f: F) -> ()
    where
        F: FnMut(&Message) -> bool + Send + 'static,
    {
        let mut rule = MatchRule::new();
        rule.msg_type = Some(dbus::message::MessageType::Signal);
        rule.interface = Some("org.freedesktop.DBus.Properties".into());
        rule.member = Some("PropertiesChanged".into());
        rule.path = Some("/org/gnu/Emacs/Org/Clock".into());

        self.connection
            .add_match(rule, move |_: (), _, msg| f(&msg))
            .unwrap();
    }

    pub fn event_loop(&self) {
        loop {
            self.connection.process(Duration::from_secs(60)).unwrap();
        }
    }

    pub fn get_starting_state(&self) -> Result<State, Box<dyn Error>> {
        let method = Message::new_method_call(
            "org.gnu.Emacs.Org.Clock",
            "/org/gnu/Emacs/Org/Clock",
            "org.freedesktop.DBus.Properties",
            "Get",
        )?
        .append2("org.gnu.Emacs.Org.Clock", "state");

        let result = self
            .connection
            .send_with_reply_and_block(method, Duration::from_millis(5000))?;
        let props: dbus::arg::Variant<dbus::arg::PropMap> = result.read1()?;
        Self::decode_state(&props.0)
    }

    pub fn clock_stop(&self) -> Result<(), Box<dyn Error>> {
        let method = Message::new_method_call(
            "org.gnu.Emacs.Org.Clock",
            "/org/gnu/Emacs/Org/Clock",
            "org.gnu.Emacs.Org.Clock",
            "Stop",
        )?;

        self.connection
            .send_with_reply_and_block(method, Duration::from_millis(5000))?;

        Ok(())
    }

    pub fn decode_state(props: &dbus::arg::PropMap) -> Result<State, Box<dyn Error>> {
        use dbus::arg::prop_cast;
        let started_prop: Option<&u64> = prop_cast(&props, "started");

        if let Some(started) = started_prop {
            let started_at = DateTime::from(UNIX_EPOCH + Duration::from_secs(*started));
            let heading: Option<&String> = prop_cast(&props, "heading");

            Ok(State::Running {
                started_at,
                heading: heading
                    .map(|x| x.to_string())
                    .unwrap_or(String::from("missing")),
            })
        } else {
            Ok(State::Stopped)
        }
    }

    pub fn decode_prop_change_message(msg: &Message) -> Option<State> {
        use dbus::arg::{cast, PropMap};
        let (arg0, arg1): (Option<String>, Option<PropMap>) = msg.get2();
        arg0.filter(|s| s == "org.gnu.Emacs.Org.Clock")?;

        let properties = arg1?;
        let state_props = properties.get("state")?;
        let casted: &PropMap = cast(&state_props.0)?;

        Self::decode_state(&casted).ok()
    }
}
