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
use serde_json::json;
use std::collections::HashMap;
use std::time::Duration;
use strfmt::strfmt;

use crate::cli::{MonitorArgs, OutputMode};

#[derive(Debug)]
pub enum State {
    Stopped,

    Running {
        started_at: DateTime<Local>,
        heading: String,
    },
}

#[derive(Debug)]
pub struct Clock {
    pub state: State,
    mode: OutputMode,
    format: String,
    down_from: Option<Duration>,
}

impl Clock {
    pub fn new(args: MonitorArgs) -> Clock {
        let down_from = args
            .down_from
            .map(|s| match s.parse::<humantime::Duration>() {
                Ok(duration) => duration.into(),
                Err(_) => {
                    eprintln!("Error: invalid --down-from value: {}", s);
                    std::process::exit(1)
                }
            });

        Clock {
            state: State::Stopped,
            mode: args.mode,
            format: args.format,
            down_from,
        }
    }

    pub fn output(&self) {
        match &self.state {
            State::Stopped => {
                self.output_stopped_msg();
            }
            State::Running {
                heading,
                started_at,
            } => {
                let mut vars: HashMap<String, String> = HashMap::new();
                vars.insert("heading".to_string(), heading.clone());

                let delta = if let Some(duration) = self.down_from {
                    (*started_at + duration) - Local::now()
                } else {
                    Local::now() - started_at
                };

                let mins = delta.num_minutes() % 60;
                let hours = delta.num_minutes() / 60;

                let time_str = format!("{:0>2}:{:0>2}", hours, mins);
                vars.insert("time".to_string(), time_str);

                match strfmt(self.format.as_str(), &vars) {
                    Ok(title) => self.output_running_msg(&title),
                    Err(e) => println!("{:?}", e),
                }
            }
        }
    }

    fn output_stopped_msg(&self) {
        match &self.mode {
            OutputMode::Simple => println!(""),
            OutputMode::Waybar => {
                let msg = json!({
                    "text": "",
                    "alt": "stopped",
                    "tooltip": "",
                    "class": "stopped",
                    "percentage": "",
                });
                println!("{}", msg.to_string());
            }
        }
    }

    fn output_running_msg(&self, title: &String) {
        match &self.mode {
            OutputMode::Simple => println!("{}", title),
            OutputMode::Waybar => {
                let msg = json!({
                    "text": title,
                    "alt": "running",
                    "tooltip": title,
                    "class": "running",
                    "percentage": "",
                });
                println!("{}", msg.to_string());
            }
        }
    }
}
