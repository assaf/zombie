#include <v8.h>
#include <node.h>

using namespace node;
using namespace v8;

class WindowContext: ObjectWrap {
private:
  int m_count;
  Handle<ObjectTemplate> global;
  Persistent<Context> context;

public:

  static Persistent<FunctionTemplate> s_ct;
  static void Init(Handle<Object> target) {
    HandleScope scope;

    Local<FunctionTemplate> t = FunctionTemplate::New(New);

    s_ct = Persistent<FunctionTemplate>::New(t);
    s_ct->InstanceTemplate()->SetInternalFieldCount(1);
    s_ct->SetClassName(String::NewSymbol("WindowContext"));

    //NODE_SET_PROTOTYPE_METHOD(s_ct, "global", GetGlobal);
    NODE_SET_PROTOTYPE_METHOD(s_ct, "evaluate", Evaluate);

    target->Set(String::NewSymbol("WindowContext"), s_ct->GetFunction());
  }

  WindowContext() : m_count(0) {
    global = ObjectTemplate::New();
    context = Context::New(NULL, global);
  }

  ~WindowContext() {
  }

  static Handle<Value> New(const Arguments& args) {
    HandleScope scope;
    WindowContext* hw = new WindowContext();
    hw->Wrap(args.This());
    return args.This();
  }

  static Handle<Value> Evaluate(const Arguments& args) {
    HandleScope scope;
    WindowContext* wc = ObjectWrap::Unwrap<WindowContext>(args.This());
    Context::Scope context_scope(wc->context);
    Local<String> source = args[0]->ToString();
    Handle<Script> script = Script::Compile(source);
    Handle<Value> result = script->Run();
    return scope.Close(result);
  }

};

Persistent<FunctionTemplate> WindowContext::s_ct;

extern "C" {
  static void init(Handle<Object> target) {
    WindowContext::Init(target);
  }
  NODE_MODULE(windowcontext, init);
}

