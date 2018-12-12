.PHONY: clean
.PHONY: error

error:
	@echo "To run a TC, go to src/ts and do a make there. Only target supported here is 'clean'."

clean:
	@echo "Removing object folder."
	rm -rf obj/
