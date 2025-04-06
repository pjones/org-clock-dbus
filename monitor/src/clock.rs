/*
   This file is part of the package org-clock-dbus. It is subject to
   the license terms in the LICENSE file found in the top-level
   directory of this distribution and at:

     https://github.com/pjones/org-clock-dbus

   No part of this package, including this file, may be copied,
   modified, propagated, or distributed except according to the terms
   contained in the LICENSE file.
*/

use chrono::{DateTime, Local, TimeDelta};
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

#[derive(Debug)]
pub struct Message {
    pub title: String,
    pub negative: bool,
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

                let negative = delta < TimeDelta::zero();
                let abs_min = delta.abs().num_minutes();

                let mins = abs_min % 60;
                let hours = abs_min / 60;

                let time_str = format!(
                    "{}{:0>2}:{:0>2}",
                    if negative { "-" } else { "" },
                    hours,
                    mins
                );

                vars.insert("time".to_string(), time_str);

                match strfmt(self.format.as_str(), &vars) {
                    Ok(title) => {
                        let msg = Message { title, negative };
                        self.output_running_msg(&msg)
                    }
                    Err(e) => println!("{:?}", e),
                }
            }
        }
    }

    fn output_stopped_msg(&self) {
        match &self.mode {
            OutputMode::Simple => println!(""),
            OutputMode::Waybar => {
                let output = json!({
                    "text": "",
                    "alt": "stopped",
                    "tooltip": "",
                    "class": ["stopped"],
                    "percentage": "",
                });
                println!("{}", output.to_string());
            }
        }
    }

    fn output_running_msg(&self, msg: &Message) {
        match &self.mode {
            OutputMode::Simple => println!("{}", msg.title),
            OutputMode::Waybar => {
                let mut classes = Vec::new();
                classes.push("running");

                if msg.negative {
                    classes.push("negative");
                }

                let output = json!({
                    "text": msg.title,
                    "alt": "running",
                    "tooltip": msg.title,
                    "class": classes,
                    "percentage": "",
                });
                println!("{}", output.to_string());
            }
        }
    }
}
