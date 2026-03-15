
import streamlit as st
import sqlite3
import pandas as pd

DB="usage.db"

st.title("Claude Code Usage Monitor")

con=sqlite3.connect(DB)
df=pd.read_sql_query("SELECT * FROM usage",con)

if df.empty:
    st.warning("No data yet")
else:
    st.subheader("Raw data")
    st.dataframe(df)

    st.subheader("Tokens per model")
    st.bar_chart(df.groupby("model")["tokens"].sum())

    st.subheader("Cost per repo")
    st.bar_chart(df.groupby("repo")["cost"].sum())

    st.subheader("Usage over time")
    df["timestamp"]=pd.to_datetime(df["timestamp"])
    df=df.sort_values("timestamp")
    st.line_chart(df.set_index("timestamp")["tokens"])
