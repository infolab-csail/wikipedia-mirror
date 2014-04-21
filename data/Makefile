FLAGS=-Wall -O2

page_remover: page_remover.c
	$(CC) $(FLAGS) -pthread $^ -o $@

.PHONY:
clean:
	rm -rf page_remover delete_me

.PHONY:
page_remover_test: page_remover
	echo "Hello world!" > ./delete_me
	./page_remover ./delete_me 5 6
	[[ $$(cat ./delete_me) = "Hello      !" ]]
