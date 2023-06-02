# Using combustion

The script here runs all the scripts in order where the script name needs to be `??_*.sh`

The execution of scripts is wrapped via tukit so the usual way doesn't work:

```bash
for i in ./*.sh; do
	${i}
done
```

That's why they are copied and then appended to the `script` file.